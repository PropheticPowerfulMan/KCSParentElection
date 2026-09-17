-- Optional presentations, auditable candidate withdrawal, and complete voter-facing profiles
begin;

alter table candidate_applications add column if not exists candidate_id uuid references candidates(id) on delete set null;
alter table candidate_applications drop constraint if exists candidate_applications_status_check;
alter table candidate_applications add constraint candidate_applications_status_check check(status in('PENDING','APPROVED','REJECTED','WITHDRAWN'));

update candidate_applications a
set candidate_id=(l.metadata->>'candidate_id')::uuid
from audit_logs l
where a.candidate_id is null and a.status='APPROVED' and l.entity_type='candidate_application' and l.entity_id=a.id::text
 and l.action='CANDIDACY_APPROVED' and coalesce(l.metadata->>'candidate_id','')~'^[0-9a-fA-F-]{36}$';

update candidate_applications a set candidate_id=(select c.id from candidates c where c.election_id=a.election_id and c.first_name=a.first_name and coalesce(c.middle_name,'')=coalesce(a.middle_name,'') and c.last_name=a.last_name and c.active order by c.created_at desc limit 1)
where a.candidate_id is null and a.status='APPROVED';

create or replace function submit_candidate_application(p_first_name text,p_middle_name text,p_last_name text,p_phone text,p_email text,p_parent_seniority integer,p_relationship text,p_position_name text,p_biography text,p_manifesto text,p_children jsonb)
returns uuid language plpgsql security definer set search_path=public,extensions as $$
declare eid uuid;aid uuid;child jsonb;
begin
 select id into eid from elections where status in('DRAFT','SCHEDULED') order by created_at desc limit 1;
 if eid is null then raise exception 'APPLICATIONS_CLOSED';end if;
 if length(trim(coalesce(p_first_name,'')))<2 or length(trim(coalesce(p_middle_name,'')))<2 or length(trim(coalesce(p_last_name,'')))<2 then raise exception 'INVALID_PARENT_NAME';end if;
 if length(trim(coalesce(p_phone,'')))<6 or position('@' in coalesce(p_email,''))<2 then raise exception 'INVALID_CONTACT_INFORMATION';end if;
 if p_parent_seniority not between 0 and 50 then raise exception 'INVALID_SENIORITY';end if;
 if p_relationship not in('Father','Mother','Guardian') or p_position_name not in('PRESIDENT','SECRETARY','TREASURER') then raise exception 'INVALID_SELECTION';end if;
 if jsonb_typeof(p_children)<>'array' or jsonb_array_length(p_children) not between 1 and 20 then raise exception 'INVALID_CHILDREN';end if;
 insert into candidate_applications(election_id,first_name,middle_name,last_name,phone,email,parent_seniority,relationship,position_name,biography,manifesto)
 values(eid,trim(p_first_name),trim(p_middle_name),trim(p_last_name),trim(p_phone),lower(trim(p_email)),p_parent_seniority,p_relationship,p_position_name,trim(coalesce(p_biography,'')),null) returning id into aid;
 for child in select * from jsonb_array_elements(p_children) loop
  if length(trim(coalesce(child->>'last_name','')))<2 or length(trim(coalesce(child->>'middle_name','')))<2 or length(trim(coalesce(child->>'first_name','')))<2 or coalesce(trim(child->>'student_class'),'')='' then raise exception 'INCOMPLETE_CHILD_INFORMATION';end if;
  insert into candidate_application_children(application_id,last_name,middle_name,first_name,student_class) values(aid,trim(child->>'last_name'),trim(child->>'middle_name'),trim(child->>'first_name'),trim(child->>'student_class'));
 end loop;
 return aid;
exception when unique_violation then raise exception 'APPLICATION_ALREADY_EXISTS';
end$$;
revoke all on function submit_candidate_application(text,text,text,text,text,integer,text,text,text,text,jsonb) from public;
grant execute on function submit_candidate_application(text,text,text,text,text,integer,text,text,text,text,jsonb) to anon,authenticated;

create or replace function review_candidate_application(p_application_id uuid,p_decision text)
returns uuid language plpgsql security definer set search_path=public,extensions as $$
declare a candidate_applications%rowtype;pid uuid;cid uuid;next_number integer;previous text;payload text;
begin
 select * into a from candidate_applications where id=p_application_id for update;
 if not found then raise exception 'APPLICATION_NOT_FOUND';end if;
 if not is_admin(a.election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]) then raise exception 'NOT_AUTHORIZED';end if;
 if a.status<>'PENDING' then raise exception 'APPLICATION_ALREADY_REVIEWED';end if;
 if p_decision not in('APPROVED','REJECTED') then raise exception 'INVALID_DECISION';end if;
 update candidate_applications set status=p_decision where id=a.id;
 if p_decision='APPROVED' then
  select id into pid from positions where election_id=a.election_id and name=a.position_name;
  if pid is null then raise exception 'POSITION_NOT_FOUND';end if;
  select coalesce(max(ballot_number),0)+1 into next_number from candidates where election_id=a.election_id;
  insert into candidates(election_id,position_id,first_name,middle_name,last_name,photo_url,biography,manifesto,ballot_number,active)
  values(a.election_id,pid,a.first_name,a.middle_name,a.last_name,a.photo_url,coalesce(a.biography,''),a.manifesto,next_number,true) returning id into cid;
  update candidate_applications set candidate_id=cid where id=a.id;
 end if;
 select entry_hash into previous from audit_logs where election_id=a.election_id order by id desc limit 1;
 payload=concat_ws('|',a.election_id::text,auth.uid()::text,'CANDIDACY_'||p_decision,a.id::text,coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash)
 values(a.election_id,auth.uid(),'CANDIDACY_'||p_decision,'candidate_application',a.id::text,jsonb_build_object('candidate_id',cid),previous,encode(digest(payload,'sha256'),'hex'));
 return cid;
end$$;
revoke all on function review_candidate_application(uuid,text) from public;
grant execute on function review_candidate_application(uuid,text) to authenticated;

create or replace function withdraw_approved_candidate(p_application_id uuid)
returns void language plpgsql security definer set search_path=public,extensions as $$
declare a candidate_applications%rowtype;e elections%rowtype;previous text;payload text;
begin
 select * into a from candidate_applications where id=p_application_id for update;
 if not found or a.status<>'APPROVED' or a.candidate_id is null then raise exception 'CANDIDATE_NOT_ACTIVE';end if;
 if not is_admin(a.election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]) then raise exception 'NOT_AUTHORIZED';end if;
 select * into e from elections where id=a.election_id for update;
 if now()>=e.start_at or e.status in('OPEN','CLOSED','RESULTS_PUBLISHED') then raise exception 'ELECTION_CONFIGURATION_IS_FROZEN';end if;
 if exists(select 1 from ballot_choices where candidate_id=a.candidate_id) then raise exception 'CANDIDATE_HAS_RECORDED_VOTES';end if;
 update candidates set active=false where id=a.candidate_id and election_id=a.election_id;
 update candidate_applications set status='WITHDRAWN' where id=a.id;
 select entry_hash into previous from audit_logs where election_id=a.election_id order by id desc limit 1;
 payload=concat_ws('|',a.election_id::text,auth.uid()::text,'CANDIDATE_WITHDRAWN',a.candidate_id::text,coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash)
 values(a.election_id,auth.uid(),'CANDIDATE_WITHDRAWN','candidate',a.candidate_id::text,jsonb_build_object('application_id',a.id),previous,encode(digest(payload,'sha256'),'hex'));
end$$;
revoke all on function withdraw_approved_candidate(uuid) from public;
grant execute on function withdraw_approved_candidate(uuid) to authenticated;

create or replace function can_read_candidate_photo(p_application_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from candidate_applications a where a.id=p_application_id and ((a.status='APPROVED' and exists(select 1 from candidates c where c.id=a.candidate_id and c.active)) or is_admin(a.election_id,array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[])))
$$;
revoke all on function can_read_candidate_photo(uuid) from public;
grant execute on function can_read_candidate_photo(uuid) to anon,authenticated;
drop policy if exists candidate_photo_admin_read on storage.objects;
drop policy if exists candidate_photo_profile_read on storage.objects;
create policy candidate_photo_profile_read on storage.objects for select to anon,authenticated using(bucket_id='candidate-photos' and can_read_candidate_photo((storage.foldername(name))[1]::uuid));

create or replace function get_voter_ballot(p_session_token text)
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare s voter_sessions%rowtype;e elections%rowtype;
begin
 select * into s from voter_sessions where token_hash=encode(digest(p_session_token,'sha256'),'hex') and used_at is null and expires_at>=now();
 if not found then return null;end if;select * into e from elections where id=s.election_id;
 return jsonb_build_object('election_id',e.id,'title',e.title,'status',e.status,'start_at',e.start_at,'end_at',e.end_at,'allow_abstention',e.allow_abstention,
  'positions',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'display_order',p.display_order,'candidates',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'first_name',c.first_name,'middle_name',c.middle_name,'last_name',c.last_name,'biography',c.biography,'photo_url',c.photo_url,'ballot_number',c.ballot_number,'relationship',a.relationship,'parent_seniority',a.parent_seniority,'children',coalesce((select jsonb_agg(jsonb_build_object('first_name',ch.first_name,'middle_name',ch.middle_name,'last_name',ch.last_name,'student_class',ch.student_class) order by ch.created_at) from candidate_application_children ch where ch.application_id=a.id),'[]'::jsonb)) order by c.ballot_number) from candidates c left join candidate_applications a on a.candidate_id=c.id and a.status='APPROVED' where c.position_id=p.id and c.election_id=e.id and c.active),'[]'::jsonb)) order by p.display_order) from positions p where p.election_id=e.id),'[]'::jsonb));
end$$;
revoke all on function get_voter_ballot(text) from public;
grant execute on function get_voter_ballot(text) to anon,authenticated;

commit;