-- Complete secure administrative candidacy workflow
begin;

create or replace function get_admin_context()
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare eid uuid; admin_role_value admin_role;
begin
 select ar.election_id,ar.role into eid,admin_role_value from admin_roles ar join elections e on e.id=ar.election_id where ar.user_id=auth.uid() order by e.created_at desc limit 1;
 if eid is null then raise exception 'NOT_AUTHORIZED'; end if;
 return jsonb_build_object('election_id',eid,'role',admin_role_value);
end$$;
revoke all on function get_admin_context() from public;
grant execute on function get_admin_context() to authenticated;

create or replace function get_candidate_applications()
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare eid uuid;
begin
 select ar.election_id into eid from admin_roles ar join elections e on e.id=ar.election_id where ar.user_id=auth.uid() and ar.role=any(array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[]) order by e.created_at desc limit 1;
 if eid is null then raise exception 'NOT_AUTHORIZED'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'first_name',a.first_name,'middle_name',a.middle_name,'last_name',a.last_name,'phone',a.phone,'email',a.email,'parent_seniority',a.parent_seniority,'relationship',a.relationship,'position_name',a.position_name,'biography',a.biography,'manifesto',a.manifesto,'photo_url',a.photo_url,'status',a.status,'created_at',a.created_at,'children',coalesce((select jsonb_agg(jsonb_build_object('first_name',ch.first_name,'middle_name',ch.middle_name,'last_name',ch.last_name,'student_class',ch.student_class) order by ch.created_at) from candidate_application_children ch where ch.application_id=a.id),'[]'::jsonb)) order by case a.status when 'PENDING' then 0 when 'APPROVED' then 1 else 2 end,a.created_at desc) from candidate_applications a where a.election_id=eid),'[]'::jsonb);
end$$;
revoke all on function get_candidate_applications() from public;
grant execute on function get_candidate_applications() to authenticated;

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
  if pid is null then raise exception 'POSITION_NOT_FOUND'; end if;
  select coalesce(max(ballot_number),0)+1 into next_number from candidates where election_id=a.election_id;
  insert into candidates(election_id,position_id,first_name,middle_name,last_name,photo_url,biography,manifesto,ballot_number,active)
  values(a.election_id,pid,a.first_name,a.middle_name,a.last_name,a.photo_url,a.biography,a.manifesto,next_number,true) returning id into cid;
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
