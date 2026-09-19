-- Fix voter authentication when the same voter code exists in several elections.
begin;

create or replace function authenticate_voter(p_voter_code text,p_pin text)
returns table(session_token text,election_id uuid,expires_at timestamptz,parent_name text)
language plpgsql security definer set search_path=public,extensions as $$
declare
 v voters%rowtype;
 e elections%rowtype;
 token text;
 normalized_code text:=upper(trim(coalesce(p_voter_code,'')));
 normalized_pin text:=trim(coalesce(p_pin,''));
begin
 if normalized_code='' or normalized_pin='' then raise exception 'INVALID_CREDENTIALS';end if;

 select vr.* into v
 from voters vr
 join elections el on el.id=vr.election_id
 where upper(trim(vr.voter_code))=normalized_code
   and el.status in('SCHEDULED','OPEN')
   and now()>=el.start_at-interval '30 minutes'
   and now()<=el.end_at
 order by el.start_at desc,vr.created_at desc
 limit 1 for update of vr;

 if not found then
  insert into login_attempts(voter_code,successful) values(left(normalized_code,80),false);
  if exists(select 1 from voters vr where upper(trim(vr.voter_code))=normalized_code) then
   raise exception 'ELECTION_LOGIN_CLOSED';
  end if;
  raise exception 'INVALID_CREDENTIALS';
 end if;

 select * into e from elections where id=v.election_id;
 if v.locked_until is not null and v.locked_until>now() then raise exception 'ACCOUNT_TEMPORARILY_LOCKED';end if;
 if crypt(normalized_pin,v.pin_hash)<>v.pin_hash then
  update voters
  set failed_attempts=failed_attempts+1,
      locked_until=case when failed_attempts+1>=5 then now()+interval '15 minutes' else null end,
      updated_at=now()
  where id=v.id;
  insert into login_attempts(voter_code,successful) values(v.voter_code,false);
  raise exception 'INVALID_CREDENTIALS';
 end if;
 if not v.eligible then raise exception 'VOTER_NOT_ELIGIBLE';end if;
 if v.has_voted then raise exception 'VOTER_ALREADY_VOTED';end if;

 token=gen_random_uuid()::text||gen_random_uuid()::text;
 update voters set failed_attempts=0,locked_until=null,updated_at=now() where id=v.id;
 insert into login_attempts(voter_code,successful) values(v.voter_code,true);
 delete from voter_sessions where voter_id=v.id and (used_at is not null or expires_at<now());
 insert into voter_sessions(voter_id,election_id,token_hash,expires_at)
 values(v.id,e.id,encode(digest(token,'sha256'),'hex'),least(e.end_at,now()+interval '90 minutes'));
 return query select token,e.id,least(e.end_at,now()+interval '90 minutes'),trim(concat_ws(' ',v.first_name,v.last_name));
end$$;

revoke all on function authenticate_voter(text,text) from public;
grant execute on function authenticate_voter(text,text) to anon,authenticated;
commit;
