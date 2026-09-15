-- Secure online candidacy submission and KCS approval workflow
begin;
alter table candidate_applications add column if not exists election_id uuid references elections on delete cascade;
alter table candidate_applications add column if not exists middle_name text;
update candidate_applications set election_id=(select id from elections where title='KCS Parent Election 2026' order by created_at desc limit 1) where election_id is null;
alter table candidate_applications alter column election_id set not null;
create unique index if not exists one_application_per_parent_election on candidate_applications(election_id,lower(email));

create or replace function submit_candidate_application(p_first_name text,p_middle_name text,p_last_name text,p_phone text,p_email text,p_parent_seniority integer,p_relationship text,p_position_name text,p_biography text,p_manifesto text,p_children jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare eid uuid;aid uuid;child jsonb;
begin
 select id into eid from elections where status in('DRAFT','SCHEDULED') order by created_at desc limit 1;
 if eid is null then raise exception 'APPLICATIONS_CLOSED';end if;
 if length(trim(p_first_name))<2 or length(trim(p_last_name))<2 or length(trim(p_phone))<6 or position('@' in p_email)<2 then raise exception 'INVALID_PERSONAL_INFORMATION';end if;
 if p_parent_seniority not between 0 and 50 then raise exception 'INVALID_SENIORITY';end if;
 if p_relationship not in('Father','Mother','Guardian') or p_position_name not in('PRESIDENT','SECRETARY','TREASURER') then raise exception 'INVALID_SELECTION';end if;
 if length(trim(p_biography))<20 or length(trim(p_manifesto))<20 then raise exception 'APPLICATION_TEXT_TOO_SHORT';end if;
 if jsonb_typeof(p_children)<>'array' or jsonb_array_length(p_children) not between 1 and 10 then raise exception 'INVALID_CHILDREN';end if;
 insert into candidate_applications(election_id,first_name,middle_name,last_name,phone,email,parent_seniority,relationship,position_name,biography,manifesto)
 values(eid,trim(p_first_name),nullif(trim(p_middle_name),''),trim(p_last_name),trim(p_phone),lower(trim(p_email)),p_parent_seniority,p_relationship,p_position_name,trim(p_biography),trim(p_manifesto)) returning id into aid;
 for child in select * from jsonb_array_elements(p_children) loop
  if coalesce(trim(child->>'last_name'),'')='' or coalesce(trim(child->>'middle_name'),'')='' or coalesce(trim(child->>'first_name'),'')='' or coalesce(trim(child->>'student_class'),'')='' then raise exception 'INCOMPLETE_CHILD_INFORMATION';end if;
  insert into candidate_application_children(application_id,last_name,middle_name,first_name,student_class) values(aid,trim(child->>'last_name'),trim(child->>'middle_name'),trim(child->>'first_name'),trim(child->>'student_class'));
 end loop;
 return aid;
end$$;
revoke all on function submit_candidate_application(text,text,text,text,text,integer,text,text,text,text,jsonb) from public;
grant execute on function submit_candidate_application(text,text,text,text,text,integer,text,text,text,text,jsonb) to anon,authenticated;

create or replace function review_candidate_application(p_application_id uuid,p_decision text)
returns uuid language plpgsql security definer set search_path=public as $$
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
  select coalesce(max(ballot_number),0)+1 into next_number from candidates where election_id=a.election_id;
  insert into candidates(election_id,position_id,first_name,middle_name,last_name,biography,manifesto,ballot_number,active)
  values(a.election_id,pid,a.first_name,a.middle_name,a.last_name,a.biography,a.manifesto,next_number,true) returning id into cid;
 end if;
 select entry_hash into previous from audit_logs where election_id=a.election_id order by id desc limit 1;
 payload=concat_ws('|',a.election_id::text,auth.uid()::text,'CANDIDACY_'||p_decision,a.id::text,coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash)
 values(a.election_id,auth.uid(),'CANDIDACY_'||p_decision,'candidate_application',a.id::text,jsonb_build_object('candidate_id',cid),previous,encode(digest(payload,'sha256'),'hex'));
 return cid;
end$$;
revoke all on function review_candidate_application(uuid,text) from public;
grant execute on function review_candidate_application(uuid,text) to authenticated;
commit;
