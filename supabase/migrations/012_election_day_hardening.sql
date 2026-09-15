-- Election-day authentication, ballot scoping and active-candidate hardening
begin;

create or replace function authenticate_voter(p_voter_code text,p_pin text)
returns table(session_token text,election_id uuid,expires_at timestamptz,parent_name text)
language plpgsql security definer set search_path=public,extensions as $$
declare v voters%rowtype;e elections%rowtype;token text;
begin
 select * into v from voters where upper(voter_code)=upper(trim(p_voter_code)) order by created_at desc limit 1 for update;
 if not found then insert into login_attempts(voter_code,successful) values(left(trim(p_voter_code),80),false);return;end if;
 select * into e from elections where id=v.election_id;
 if v.locked_until is not null and v.locked_until>now() then return;end if;
 if crypt(p_pin,v.pin_hash)<>v.pin_hash then
  update voters set failed_attempts=failed_attempts+1,locked_until=case when failed_attempts+1>=5 then now()+interval '15 minutes' else null end,updated_at=now() where id=v.id;
  insert into login_attempts(voter_code,successful) values(v.voter_code,false);return;
 end if;
 if not v.eligible or v.has_voted then return;end if;
 if e.status not in('SCHEDULED','OPEN') or now()<e.start_at-interval '30 minutes' or now()>e.end_at then return;end if;
 token=gen_random_uuid()::text||gen_random_uuid()::text;
 update voters set failed_attempts=0,locked_until=null,updated_at=now() where id=v.id;
 insert into login_attempts(voter_code,successful) values(v.voter_code,true);
 delete from voter_sessions where voter_id=v.id and (used_at is not null or expires_at<now());
 insert into voter_sessions(voter_id,election_id,token_hash,expires_at) values(v.id,e.id,encode(digest(token,'sha256'),'hex'),least(e.end_at,now()+interval '90 minutes'));
 return query select token,e.id,least(e.end_at,now()+interval '90 minutes'),trim(concat_ws(' ',v.first_name,v.last_name));
end$$;
revoke all on function authenticate_voter(text,text) from public;grant execute on function authenticate_voter(text,text) to anon,authenticated;

create or replace function get_voter_ballot(p_session_token text)
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare s voter_sessions%rowtype;e elections%rowtype;
begin
 select * into s from voter_sessions where token_hash=encode(digest(p_session_token,'sha256'),'hex') and used_at is null and expires_at>=now();
 if not found then return null;end if;select * into e from elections where id=s.election_id;
 return jsonb_build_object('election_id',e.id,'title',e.title,'status',e.status,'start_at',e.start_at,'end_at',e.end_at,'allow_abstention',e.allow_abstention,
  'positions',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'display_order',p.display_order,'candidates',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'first_name',c.first_name,'middle_name',c.middle_name,'last_name',c.last_name,'biography',c.biography,'manifesto',c.manifesto,'photo_url',c.photo_url,'ballot_number',c.ballot_number) order by c.ballot_number) from candidates c where c.position_id=p.id and c.election_id=e.id and c.active),'[]'::jsonb)) order by p.display_order) from positions p where p.election_id=e.id),'[]'::jsonb));
end$$;
revoke all on function get_voter_ballot(text) from public;grant execute on function get_voter_ballot(text) to anon,authenticated;

create or replace function submit_ballot(p_voter_id uuid,p_election_id uuid,p_choices jsonb,p_idempotency_key uuid)
returns table(confirmation_code text,submitted_at timestamptz) language plpgsql security definer set search_path=public,extensions as $$
declare v voters%rowtype;e elections%rowtype;b uuid;item jsonb;expected int;selected_candidate uuid;is_abstention boolean;
begin
 select * into v from voters where id=p_voter_id and election_id=p_election_id for update;
 if not found or not v.eligible then raise exception 'VOTER_NOT_ELIGIBLE';end if;if v.has_voted then raise exception 'ALREADY_VOTED';end if;
 select * into e from elections where id=p_election_id for share;if e.status<>'OPEN' or now()<e.start_at or now()>e.end_at then raise exception 'ELECTION_NOT_OPEN';end if;
 if jsonb_typeof(p_choices)<>'array' then raise exception 'INVALID_BALLOT';end if;select count(*) into expected from positions where election_id=p_election_id;
 if jsonb_array_length(p_choices)<>expected then raise exception 'INCOMPLETE_BALLOT';end if;
 insert into ballots(election_id,idempotency_key) values(p_election_id,p_idempotency_key) returning id into b;
 for item in select * from jsonb_array_elements(p_choices) loop
  is_abstention=coalesce((item->>'abstained')::boolean,false);selected_candidate=null;
  if is_abstention and not e.allow_abstention then raise exception 'ABSTENTION_DISABLED';end if;
  if not exists(select 1 from positions p where p.id=(item->>'position_id')::uuid and p.election_id=p_election_id) then raise exception 'INVALID_POSITION';end if;
  if not is_abstention then
   select c.id into selected_candidate from candidates c where c.id=(item->>'candidate_id')::uuid and c.position_id=(item->>'position_id')::uuid and c.election_id=p_election_id and c.active;
   if selected_candidate is null then raise exception 'INVALID_OR_INACTIVE_CANDIDATE';end if;
  end if;
  insert into ballot_choices(ballot_id,election_id,position_id,candidate_id,abstained) values(b,p_election_id,(item->>'position_id')::uuid,selected_candidate,is_abstention);
 end loop;
 if (select count(*) from ballot_choices where ballot_id=b)<>expected then raise exception 'INVALID_BALLOT';end if;
 update voters set has_voted=true,voted_at=now(),pin_hash=crypt(gen_random_uuid()::text,gen_salt('bf')),updated_at=now() where id=v.id;
 return query select upper(substr(replace(b::text,'-',''),1,12)),x.submitted_at from ballots x where x.id=b;
end$$;
revoke all on function submit_ballot(uuid,uuid,jsonb,uuid) from public;grant execute on function submit_ballot(uuid,uuid,jsonb,uuid) to service_role;

alter table candidate_applications drop constraint if exists approved_application_requires_photo;
alter table candidate_applications add constraint approved_application_requires_photo check(status<>'APPROVED' or photo_url is not null);
create index if not exists login_attempts_code_created_idx on login_attempts(voter_code,created_at desc);

create or replace function freeze_voter_registry_at_opening() returns trigger language plpgsql set search_path=public as $$
declare eid uuid;opening timestamptz;
begin
 eid=case when tg_op='DELETE' then old.election_id else new.election_id end;select start_at into opening from elections where id=eid;
 if now()>=opening then
  if tg_op in('INSERT','DELETE') then raise exception 'VOTER_REGISTRY_IS_FROZEN';end if;
  if new.election_id is distinct from old.election_id or new.voter_code is distinct from old.voter_code or new.eligible is distinct from old.eligible then raise exception 'VOTER_ELIGIBILITY_IS_FROZEN';end if;
 end if;return case when tg_op='DELETE' then old else new end;
end$$;
drop trigger if exists voters_frozen_at_opening on voters;
create trigger voters_frozen_at_opening before insert or update or delete on voters for each row execute function freeze_voter_registry_at_opening();

create or replace function get_official_election_results()
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare cert election_certifications%rowtype;
begin
 select ec.* into cert from election_certifications ec join elections e on e.id=ec.election_id where e.results_published order by e.end_at desc limit 1;
 if not found then return null;end if;
 return cert.summary||jsonb_build_object('report_hash',cert.report_hash,'certified_at',cert.certified_at);
end$$;
revoke all on function get_official_election_results() from public;grant execute on function get_official_election_results() to anon,authenticated;
commit;

