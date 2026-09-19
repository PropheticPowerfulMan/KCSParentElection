-- Permit administrators to reissue a PIN before the upcoming election opens.
begin;

create or replace function reissue_voter_pin(p_voter_id uuid)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare selected_v voters%rowtype;v voters%rowtype;e elections%rowtype;pin text;previous text;payload text;
begin
 select * into selected_v from voters where id=p_voter_id;
 if not found then raise exception 'VOTER_NOT_FOUND';end if;

 select vr.* into v
 from voters vr join elections el on el.id=vr.election_id
 where upper(trim(vr.voter_code))=upper(trim(selected_v.voter_code))
   and el.status in('SCHEDULED','OPEN')
   and now()<=el.end_at
 order by case when now()>=el.start_at-interval '30 minutes' then 0 else 1 end,el.start_at asc,vr.created_at desc
 limit 1 for update of vr;
 if not found then raise exception 'NO_CURRENT_OR_UPCOMING_ELECTION';end if;
 if not is_admin(v.election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]) then raise exception 'NOT_AUTHORIZED';end if;
 select * into e from elections where id=v.election_id;
 if v.has_voted then raise exception 'BALLOT_ALREADY_SUBMITTED';end if;
 if not v.eligible then raise exception 'VOTER_NOT_ELIGIBLE';end if;
 if e.results_published then raise exception 'RESULTS_ALREADY_PUBLISHED';end if;

 pin=(100000+((get_byte(gen_random_bytes(3),0)*65536+get_byte(gen_random_bytes(3),1)*256+get_byte(gen_random_bytes(3),2))%900000))::text;
 update voters set pin_hash=crypt(pin,gen_salt('bf',10)),failed_attempts=0,locked_until=null,updated_at=now() where id=v.id;
 delete from voter_sessions where voter_id=v.id and used_at is null;
 select entry_hash into previous from audit_logs where election_id=v.election_id order by id desc limit 1;
 payload=concat_ws('|',v.election_id::text,auth.uid()::text,'VOTER_PIN_REISSUED',v.id::text,coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash)
 values(v.election_id,auth.uid(),'VOTER_PIN_REISSUED','voter',v.id::text,jsonb_build_object('voter_code',v.voter_code,'upcoming_election_supported',true),previous,encode(digest(payload,'sha256'),'hex'));
 return jsonb_build_object('code',v.voter_code,'pin',pin);
end$$;

revoke all on function reissue_voter_pin(uuid) from public;
grant execute on function reissue_voter_pin(uuid) to authenticated;
commit;
