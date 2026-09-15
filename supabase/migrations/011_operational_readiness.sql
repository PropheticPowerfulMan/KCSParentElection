-- Operational readiness and secure voter credential recovery
begin;
create or replace function reissue_voter_pin(p_voter_id uuid)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v voters%rowtype;e elections%rowtype;pin text;previous text;payload text;
begin
 select * into v from voters where id=p_voter_id for update;
 if not found then raise exception 'VOTER_NOT_FOUND';end if;
 if not is_admin(v.election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]) then raise exception 'NOT_AUTHORIZED';end if;
 select * into e from elections where id=v.election_id;
 if v.has_voted then raise exception 'BALLOT_ALREADY_SUBMITTED';end if;
 if e.results_published or now()>e.end_at then raise exception 'ELECTION_FINISHED';end if;
 pin=(100000+((get_byte(gen_random_bytes(3),0)*65536+get_byte(gen_random_bytes(3),1)*256+get_byte(gen_random_bytes(3),2))%900000))::text;
 update voters set pin_hash=crypt(pin,gen_salt('bf',10)),failed_attempts=0,locked_until=null,updated_at=now() where id=v.id;
 delete from voter_sessions where voter_id=v.id and used_at is null;
 select entry_hash into previous from audit_logs where election_id=v.election_id order by id desc limit 1;
 payload=concat_ws('|',v.election_id::text,auth.uid()::text,'VOTER_PIN_REISSUED',v.id::text,coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash) values(v.election_id,auth.uid(),'VOTER_PIN_REISSUED','voter',v.id::text,jsonb_build_object('voter_code',v.voter_code),previous,encode(digest(payload,'sha256'),'hex'));
 return jsonb_build_object('code',v.voter_code,'pin',pin);
end$$;
revoke all on function reissue_voter_pin(uuid) from public;grant execute on function reissue_voter_pin(uuid) to authenticated;

create or replace function validate_election_readiness()
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare eid uuid;e elections%rowtype;issues jsonb='[]'::jsonb;position_count int;voter_count int;candidate_count int;empty_positions int;published_certifications int;
begin
 select ar.election_id into eid from admin_roles ar join elections x on x.id=ar.election_id where ar.user_id=auth.uid() order by x.created_at desc limit 1;
 if eid is null then raise exception 'NOT_AUTHORIZED';end if;select * into e from elections where id=eid;
 select count(*) into position_count from positions where election_id=eid;
 select count(*) into voter_count from voters where election_id=eid and eligible;
 select count(*) into candidate_count from candidates where election_id=eid and active;
 select count(*) into empty_positions from positions p where p.election_id=eid and not exists(select 1 from candidates c where c.position_id=p.id and c.active);
 select count(*) into published_certifications from election_certifications where election_id=eid;
 if position_count<>3 then issues=issues||jsonb_build_array('POSITION_COUNT_INVALID');end if;
 if voter_count=0 then issues=issues||jsonb_build_array('NO_ELIGIBLE_VOTERS');end if;
 if empty_positions>0 then issues=issues||jsonb_build_array('CANDIDATE_LIST_INCOMPLETE');end if;
 if e.end_at<=e.start_at then issues=issues||jsonb_build_array('INVALID_ELECTION_WINDOW');end if;
 if e.show_interim_results then issues=issues||jsonb_build_array('INTERIM_RESULTS_ENABLED');end if;
 if not e.results_published and published_certifications>0 then issues=issues||jsonb_build_array('PREMATURE_CERTIFICATION');end if;
 return jsonb_build_object('ready',jsonb_array_length(issues)=0,'issues',issues,'positions',position_count,'eligible_voters',voter_count,'active_candidates',candidate_count,'empty_positions',empty_positions,'start_at',e.start_at,'end_at',e.end_at,'status',e.status);
end$$;
revoke all on function validate_election_readiness() from public;grant execute on function validate_election_readiness() to authenticated;
commit;
