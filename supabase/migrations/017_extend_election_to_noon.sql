-- Officially extend the KCS Parent Election closing time from 11:30 to 12:00 Kinshasa time
begin;
do $$
declare eid uuid;old_end timestamptz;previous text;payload text;
begin
 select id,end_at into eid,old_end from elections
 where start_at='2026-09-19 10:30:00+01'::timestamptz
 order by created_at desc limit 1 for update;
 if eid is null then raise exception 'ELECTION_NOT_FOUND_FOR_SCHEDULE_EXTENSION';end if;
 if now()>='2026-09-19 10:30:00+01'::timestamptz then raise exception 'ELECTION_SCHEDULE_ALREADY_FROZEN';end if;
 if old_end is distinct from '2026-09-19 12:00:00+01'::timestamptz then
  update elections set end_at='2026-09-19 12:00:00+01'::timestamptz where id=eid;
  select entry_hash into previous from audit_logs where election_id=eid order by id desc limit 1;
  payload=concat_ws('|',eid::text,coalesce(auth.uid()::text,'SYSTEM'),'ELECTION_SCHEDULE_EXTENDED',old_end::text,'2026-09-19 12:00:00+01',coalesce(previous,''));
  insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash)
  values(eid,auth.uid(),'ELECTION_SCHEDULE_EXTENDED','election',eid::text,jsonb_build_object('previous_end_at',old_end,'new_end_at','2026-09-19T12:00:00+01:00','reason','Official KCS schedule extension'),previous,encode(digest(payload,'sha256'),'hex'));
 end if;
end$$;
commit;