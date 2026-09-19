-- Emergency supervised test window: 19 Sep 2026 21:54 to 20 Sep 2026 00:00 Kinshasa.
begin;

do $$
declare eid uuid;old_start timestamptz;old_end timestamptz;previous text;payload text;
begin
 select id,start_at,end_at into eid,old_start,old_end
 from elections where title='KCS Parent Election 2026'
 order by created_at desc limit 1 for update;
 if eid is null then raise exception 'ELECTION_NOT_FOUND';end if;
 if exists(select 1 from elections where id=eid and results_published) then raise exception 'RESULTS_ALREADY_PUBLISHED';end if;

 update elections
 set start_at='2026-09-19 21:54:00+01'::timestamptz,
     end_at='2026-09-20 00:00:00+01'::timestamptz,
     status='SCHEDULED'
 where id=eid;

 -- A new PIN or the existing correct PIN can be tested without stale locks.
 update voters set failed_attempts=0,locked_until=null,updated_at=now()
 where election_id=eid and eligible and not has_voted;
 delete from voter_sessions where election_id=eid and used_at is null;

 select entry_hash into previous from audit_logs where election_id=eid order by id desc limit 1;
 payload=concat_ws('|',eid::text,coalesce(auth.uid()::text,'SYSTEM'),'ELECTION_TEST_WINDOW_OPENED',old_start::text,old_end::text,'2026-09-19 21:54:00+01','2026-09-20 00:00:00+01',coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash)
 values(eid,auth.uid(),'ELECTION_TEST_WINDOW_OPENED','election',eid::text,
 jsonb_build_object('previous_start_at',old_start,'previous_end_at',old_end,'new_start_at','2026-09-19T21:54:00+01:00','new_end_at','2026-09-20T00:00:00+01:00','reason','Supervised end-to-end credential and voting test'),
 previous,encode(digest(payload,'sha256'),'hex'));
end$$;

commit;

-- Visible post-migration health report (contains no PIN or hash).
select e.id,e.title,e.status,e.start_at,e.end_at,
 count(v.id) as registered_voters,
 count(v.id) filter(where v.eligible) as eligible_voters,
 count(v.id) filter(where v.eligible and not v.has_voted) as voters_available_for_test
from elections e left join voters v on v.election_id=e.id
where e.title='KCS Parent Election 2026'
group by e.id,e.title,e.status,e.start_at,e.end_at
order by e.start_at desc limit 1;
