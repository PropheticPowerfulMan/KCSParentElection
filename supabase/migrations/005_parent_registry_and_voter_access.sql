-- Secure parent registry import and one-time voter sessions
begin;

create table if not exists voter_children(
 id uuid primary key default gen_random_uuid(),
 voter_id uuid not null references voters on delete cascade,
 election_id uuid not null references elections on delete cascade,
 student_id text not null,
 first_name text not null,
 middle_name text,
 last_name text not null,
 student_class text not null,
 created_at timestamptz not null default now(),
 unique(election_id,student_id)
);
alter table voter_children enable row level security;
create policy admins_voter_children on voter_children for select using(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[]));
create policy managers_voter_children_write on voter_children for all using(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[])) with check(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]));

create table if not exists voter_sessions(
 id uuid primary key default gen_random_uuid(),
 voter_id uuid not null references voters on delete cascade,
 election_id uuid not null references elections on delete cascade,
 token_hash text not null unique,
 expires_at timestamptz not null,
 used_at timestamptz,
 created_at timestamptz not null default now()
);
alter table voter_sessions enable row level security;
revoke all on voter_sessions from anon,authenticated;

create or replace function import_parent_registry(p_registry jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare eid uuid; item jsonb; child jsonb; vid uuid; pin text; creds jsonb='[]'::jsonb; imported int=0;
begin
 if auth.role()<>'service_role' then raise exception 'NOT_AUTHORIZED'; end if;
 select id into eid from elections where title='KCS Parent Election 2026' order by created_at desc limit 1;
 if eid is null then raise exception 'ELECTION_NOT_FOUND'; end if;
 if jsonb_typeof(p_registry)<>'array' then raise exception 'INVALID_REGISTRY'; end if;
 for item in select * from jsonb_array_elements(p_registry) loop
  if coalesce(item->>'parent_ref','')='' or jsonb_array_length(coalesce(item->'children','[]'::jsonb))<1 then raise exception 'INVALID_PARENT_RECORD'; end if;
  pin=(100000 + ((get_byte(gen_random_bytes(3),0)*65536 + get_byte(gen_random_bytes(3),1)*256 + get_byte(gen_random_bytes(3),2)) % 900000))::text;
  child=(item->'children')->0;
  insert into voters(election_id,voter_code,pin_hash,first_name,last_name,phone,email,student_name,student_id,student_class,relationship,eligible)
  values(eid,item->>'parent_ref',crypt(pin,gen_salt('bf',10)),coalesce(item->>'first_name','Parent'),coalesce(item->>'last_name','KCS'),nullif(item->>'phone',''),nullif(lower(item->>'email'),''),trim(concat_ws(' ',child->>'first_name',child->>'middle_name',child->>'last_name')),child->>'student_id',child->>'class','Guardian',true)
  on conflict(election_id,voter_code) do update set first_name=excluded.first_name,last_name=excluded.last_name,phone=excluded.phone,email=excluded.email,student_name=excluded.student_name,student_id=excluded.student_id,student_class=excluded.student_class,pin_hash=case when voters.has_voted then voters.pin_hash else excluded.pin_hash end,updated_at=now()
  returning id into vid;
  delete from voter_children where voter_id=vid;
  for child in select * from jsonb_array_elements(item->'children') loop
   insert into voter_children(voter_id,election_id,student_id,first_name,middle_name,last_name,student_class)
   values(vid,eid,child->>'student_id',coalesce(child->>'first_name',''),nullif(child->>'middle_name',''),coalesce(child->>'last_name',''),coalesce(child->>'class',''))
   on conflict(election_id,student_id) do update set voter_id=excluded.voter_id,first_name=excluded.first_name,middle_name=excluded.middle_name,last_name=excluded.last_name,student_class=excluded.student_class;
  end loop;
  creds=creds||jsonb_build_array(jsonb_build_object('parent_ref',item->>'parent_ref','voter_code',item->>'parent_ref','pin',pin)); imported=imported+1;
 end loop;
 return jsonb_build_object('imported',imported,'credentials',creds);
end$$;
revoke all on function import_parent_registry(jsonb) from public;
grant execute on function import_parent_registry(jsonb) to service_role;

create or replace function authenticate_voter(p_voter_code text,p_pin text)
returns table(session_token text,election_id uuid,expires_at timestamptz,parent_name text)
language plpgsql security definer set search_path=public as $$
declare v voters%rowtype; e elections%rowtype; token text;
begin
 select * into v from voters where upper(voter_code)=upper(trim(p_voter_code)) order by created_at desc limit 1 for update;
 if not found then insert into login_attempts(voter_code,successful) values(trim(p_voter_code),false); raise exception 'INVALID_CREDENTIALS'; end if;
 select * into e from elections where id=v.election_id;
 if v.locked_until is not null and v.locked_until>now() then raise exception 'ACCOUNT_TEMPORARILY_LOCKED'; end if;
 if crypt(p_pin,v.pin_hash)<>v.pin_hash then
  update voters set failed_attempts=failed_attempts+1,locked_until=case when failed_attempts+1>=5 then now()+interval '15 minutes' else null end where id=v.id;
  insert into login_attempts(voter_code,successful) values(v.voter_code,false); raise exception 'INVALID_CREDENTIALS';
 end if;
 if not v.eligible or v.has_voted then raise exception 'VOTER_NOT_AVAILABLE'; end if;
 if e.status not in('SCHEDULED','OPEN') or now()<e.start_at-interval '30 minutes' or now()>e.end_at then raise exception 'ELECTION_LOGIN_CLOSED'; end if;
 token=gen_random_uuid()::text||gen_random_uuid()::text;
 update voters set failed_attempts=0,locked_until=null where id=v.id;
 insert into login_attempts(voter_code,successful) values(v.voter_code,true);
 insert into voter_sessions(voter_id,election_id,token_hash,expires_at) values(v.id,e.id,encode(digest(token,'sha256'),'hex'),least(e.end_at,now()+interval '90 minutes'));
 return query select token,e.id,least(e.end_at,now()+interval '90 minutes'),trim(concat_ws(' ',v.first_name,v.last_name));
end$$;
revoke all on function authenticate_voter(text,text) from public;
grant execute on function authenticate_voter(text,text) to anon,authenticated;

create or replace function submit_voter_ballot(p_session_token text,p_choices jsonb,p_idempotency_key uuid)
returns table(confirmation_code text,submitted_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare s voter_sessions%rowtype;
begin
 select * into s from voter_sessions where token_hash=encode(digest(p_session_token,'sha256'),'hex') for update;
 if not found or s.used_at is not null or s.expires_at<now() then raise exception 'INVALID_OR_EXPIRED_SESSION'; end if;
 return query select * from submit_ballot(s.voter_id,s.election_id,p_choices,p_idempotency_key);
 update voter_sessions set used_at=now() where id=s.id;
end$$;
revoke all on function submit_voter_ballot(text,jsonb,uuid) from public;
grant execute on function submit_voter_ballot(text,jsonb,uuid) to anon,authenticated;
commit;
