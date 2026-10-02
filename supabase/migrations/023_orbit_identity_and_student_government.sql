begin;
alter table elections add column if not exists election_kind text not null default 'PARENT_COMMITTEE' check(election_kind in('PARENT_COMMITTEE','STUDENT_GOVERNMENT'));
alter table voters add column if not exists orbit_user_id text;
alter table voters add column if not exists voter_type text not null default 'PARENT' check(voter_type in('PARENT','STUDENT'));
create unique index if not exists voters_election_orbit_identity on voters(election_id,orbit_user_id) where orbit_user_id is not null;
alter table positions drop constraint if exists positions_name_check;
alter table positions add column if not exists constituency_grade text;
alter table positions add column if not exists constituency_section text;

create or replace function issue_orbit_voter_session(p_orbit_user_id text,p_email text,p_access_code text,p_first_name text,p_last_name text,p_role text,p_grade text default '',p_section text default '')
returns table(session_token text,expires_at timestamptz,display_name text,election_kind text)
language plpgsql security definer set search_path=public as $$
declare e elections%rowtype;v voters%rowtype;token text;kind text;normalized_role text=upper(trim(p_role));
begin
 if auth.role()<>'service_role' then raise exception 'NOT_AUTHORIZED';end if;
 if normalized_role not in('PARENT','STUDENT') then raise exception 'WRONG_ELECTORATE';end if;
 kind=case when normalized_role='PARENT' then 'PARENT_COMMITTEE' else 'STUDENT_GOVERNMENT' end;
 select * into e from elections where election_kind=kind and status in('SCHEDULED','OPEN') and now() between start_at-interval '30 minutes' and end_at order by start_at desc limit 1;
 if not found then raise exception 'ELECTION_LOGIN_CLOSED';end if;
 select * into v from voters where election_id=e.id and (orbit_user_id=p_orbit_user_id or (normalized_role='PARENT' and ((email is not null and lower(email)=lower(trim(p_email))) or upper(voter_code)=upper(trim(p_access_code))))) order by created_at desc limit 1 for update;
 if not found and normalized_role='STUDENT' then
  insert into voters(election_id,voter_code,pin_hash,first_name,last_name,email,student_name,student_id,student_class,relationship,eligible,orbit_user_id,voter_type)
  values(e.id,coalesce(nullif(trim(p_access_code),''),'ORB-'||substr(replace(p_orbit_user_id,'-',''),1,16)),crypt(gen_random_uuid()::text,gen_salt('bf')),coalesce(nullif(trim(p_first_name),''),'Student'),coalesce(nullif(trim(p_last_name),''),'KCS'),nullif(lower(trim(p_email)),''),trim(concat_ws(' ',p_first_name,p_last_name)),p_orbit_user_id,trim(concat_ws(' ',p_grade,p_section)),'Guardian',true,p_orbit_user_id,'STUDENT') returning * into v;
 end if;
 if not found or not v.eligible then raise exception 'VOTER_NOT_ELIGIBLE';end if;
 if v.has_voted then raise exception 'VOTER_ALREADY_VOTED';end if;
 update voters set orbit_user_id=coalesce(orbit_user_id,p_orbit_user_id),voter_type=normalized_role,failed_attempts=0,locked_until=null,updated_at=now() where id=v.id;
 token=gen_random_uuid()::text||gen_random_uuid()::text;
 insert into voter_sessions(voter_id,election_id,token_hash,expires_at) values(v.id,e.id,encode(digest(token,'sha256'),'hex'),least(e.end_at,now()+interval '45 minutes'));
 insert into audit_logs(election_id,action,entity_type,entity_id,metadata,entry_hash) values(e.id,'ORBIT_VOTER_SESSION_ISSUED','voter',v.id::text,jsonb_build_object('voter_type',normalized_role,'credential_source','KCS_ORBIT'),encode(digest(v.id::text||clock_timestamp()::text,'sha256'),'hex'));
 return query select token,least(e.end_at,now()+interval '45 minutes'),trim(concat_ws(' ',v.first_name,v.last_name)),kind;
end$$;
revoke all on function issue_orbit_voter_session(text,text,text,text,text,text,text,text) from public;
grant execute on function issue_orbit_voter_session(text,text,text,text,text,text,text,text) to service_role;

create or replace function get_voter_ballot(p_session_token text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare s voter_sessions%rowtype;v voters%rowtype;e elections%rowtype;
begin
 select * into s from voter_sessions where token_hash=encode(digest(p_session_token,'sha256'),'hex') and used_at is null and expires_at>=now();
 if not found then raise exception 'INVALID_OR_EXPIRED_SESSION';end if;
 select * into v from voters where id=s.voter_id;select * into e from elections where id=s.election_id;
 return jsonb_build_object('election',jsonb_build_object('id',e.id,'title',e.title,'end_at',e.end_at,'election_kind',e.election_kind),'voter',jsonb_build_object('id',v.id,'name',trim(concat_ws(' ',v.first_name,v.last_name)),'voter_type',v.voter_type),'positions',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'display_order',p.display_order,'constituency_grade',p.constituency_grade,'constituency_section',p.constituency_section,'candidates',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'first_name',c.first_name,'middle_name',c.middle_name,'last_name',c.last_name,'biography',c.biography,'photo_url',c.photo_url,'ballot_number',c.ballot_number) order by c.ballot_number) from candidates c where c.position_id=p.id and c.election_id=e.id and c.active),'[]'::jsonb)) order by p.display_order) from positions p where p.election_id=e.id and (p.constituency_grade is null or lower(trim(concat_ws(' ',p.constituency_grade,p.constituency_section)))=lower(trim(v.student_class)))),'[]'::jsonb));
end$$;
revoke all on function get_voter_ballot(text) from public;grant execute on function get_voter_ballot(text) to anon,authenticated;

create or replace function submit_ballot(p_voter_id uuid,p_election_id uuid,p_choices jsonb,p_idempotency_key uuid)
returns table(confirmation_code text,submitted_at timestamptz) language plpgsql security definer set search_path=public as $$
declare v voters%rowtype;e elections%rowtype;b uuid;item jsonb;expected int;selected_candidate uuid;is_abstention boolean;
begin
 select * into v from voters where id=p_voter_id and election_id=p_election_id for update;if not found or not v.eligible then raise exception 'VOTER_NOT_ELIGIBLE';end if;if v.has_voted then raise exception 'ALREADY_VOTED';end if;
 select * into e from elections where id=p_election_id for share;if e.status<>'OPEN' or now()<e.start_at or now()>e.end_at then raise exception 'ELECTION_NOT_OPEN';end if;
 select count(*) into expected from positions p where p.election_id=p_election_id and (p.constituency_grade is null or lower(trim(concat_ws(' ',p.constituency_grade,p.constituency_section)))=lower(trim(v.student_class)));
 if jsonb_typeof(p_choices)<>'array' or jsonb_array_length(p_choices)<>expected then raise exception 'INCOMPLETE_BALLOT';end if;
 insert into ballots(election_id,idempotency_key) values(p_election_id,p_idempotency_key) returning id into b;
 for item in select * from jsonb_array_elements(p_choices) loop
  is_abstention=coalesce((item->>'abstained')::boolean,false);if is_abstention and not e.allow_abstention then raise exception 'ABSTENTION_DISABLED';end if;
  if not exists(select 1 from positions p where p.id=(item->>'position_id')::uuid and p.election_id=p_election_id and (p.constituency_grade is null or lower(trim(concat_ws(' ',p.constituency_grade,p.constituency_section)))=lower(trim(v.student_class)))) then raise exception 'INVALID_POSITION';end if;
  selected_candidate=null;if not is_abstention then select c.id into selected_candidate from candidates c where c.id=(item->>'candidate_id')::uuid and c.position_id=(item->>'position_id')::uuid and c.election_id=p_election_id and c.active;if selected_candidate is null then raise exception 'INVALID_CANDIDATE';end if;end if;
  insert into ballot_choices(ballot_id,election_id,position_id,candidate_id,abstained) values(b,p_election_id,(item->>'position_id')::uuid,selected_candidate,is_abstention);
 end loop;
 update voters set has_voted=true,voted_at=now(),pin_hash=crypt(gen_random_uuid()::text,gen_salt('bf')),updated_at=now() where id=v.id;
 return query select upper(substr(replace(b::text,'-',''),1,12)),x.submitted_at from ballots x where x.id=b;
end$$;
revoke all on function submit_ballot(uuid,uuid,jsonb,uuid) from public;grant execute on function submit_ballot(uuid,uuid,jsonb,uuid) to service_role;
commit;