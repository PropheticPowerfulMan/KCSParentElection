-- Simplify candidacy: one presentation, no manifesto requirement
begin;
alter table candidate_applications alter column manifesto drop not null;

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
 if length(trim(coalesce(p_biography,'')))<10 then raise exception 'PRESENTATION_TOO_SHORT';end if;
 if jsonb_typeof(p_children)<>'array' or jsonb_array_length(p_children) not between 1 and 10 then raise exception 'INVALID_CHILDREN';end if;
 insert into candidate_applications(election_id,first_name,middle_name,last_name,phone,email,parent_seniority,relationship,position_name,biography,manifesto)
 values(eid,trim(p_first_name),trim(p_middle_name),trim(p_last_name),trim(p_phone),lower(trim(p_email)),p_parent_seniority,p_relationship,p_position_name,trim(p_biography),null) returning id into aid;
 for child in select * from jsonb_array_elements(p_children) loop
  if length(trim(coalesce(child->>'last_name','')))<2 or length(trim(coalesce(child->>'middle_name','')))<2 or length(trim(coalesce(child->>'first_name','')))<2 or coalesce(trim(child->>'student_class'),'')='' then raise exception 'INCOMPLETE_CHILD_INFORMATION';end if;
  insert into candidate_application_children(application_id,last_name,middle_name,first_name,student_class) values(aid,trim(child->>'last_name'),trim(child->>'middle_name'),trim(child->>'first_name'),trim(child->>'student_class'));
 end loop;
 return aid;
exception when unique_violation then raise exception 'APPLICATION_ALREADY_EXISTS';
end$$;
revoke all on function submit_candidate_application(text,text,text,text,text,integer,text,text,text,text,jsonb) from public;
grant execute on function submit_candidate_application(text,text,text,text,text,integer,text,text,text,text,jsonb) to anon,authenticated;
commit;
