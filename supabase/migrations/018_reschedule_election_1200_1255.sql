-- Officially reschedule the election to 12:00-12:55 Kinshasa time
begin;
do $$
declare eid uuid;old_start timestamptz;old_end timestamptz;previous text;payload text;
begin
 select id,start_at,end_at into eid,old_start,old_end from elections
 where title='KCS Parent Election 2026'
 order by created_at desc limit 1 for update;
 if eid is null then raise exception 'ELECTION_NOT_FOUND_FOR_RESCHEDULING';end if;
 if exists(select 1 from ballots where election_id=eid) then raise exception 'CANNOT_RESCHEDULE_AFTER_BALLOTS';end if;
 if now()>='2026-09-19 12:00:00+01'::timestamptz then raise exception 'NEW_ELECTION_WINDOW_ALREADY_STARTED';end if;
 update elections set start_at='2026-09-19 12:00:00+01'::timestamptz,end_at='2026-09-19 12:55:00+01'::timestamptz,status='SCHEDULED',results_published=false where id=eid;
 delete from voter_sessions where election_id=eid;
 select entry_hash into previous from audit_logs where election_id=eid order by id desc limit 1;
 payload=concat_ws('|',eid::text,coalesce(auth.uid()::text,'SYSTEM'),'ELECTION_RESCHEDULED',old_start::text,old_end::text,'2026-09-19 12:00:00+01','2026-09-19 12:55:00+01',coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash)
 values(eid,auth.uid(),'ELECTION_RESCHEDULED','election',eid::text,jsonb_build_object('previous_start_at',old_start,'previous_end_at',old_end,'new_start_at','2026-09-19T12:00:00+01:00','new_end_at','2026-09-19T12:55:00+01:00','reason','Official KCS election-day rescheduling'),previous,encode(digest(payload,'sha256'),'hex'));
end$$;
commit;