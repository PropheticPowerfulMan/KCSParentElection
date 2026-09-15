-- Open the scheduled election automatically on the first valid ballot in the official window.
begin;
create or replace function submit_voter_ballot(p_session_token text,p_choices jsonb,p_idempotency_key uuid)
returns table(confirmation_code text,submitted_at timestamptz)
language plpgsql security definer set search_path=public,extensions as $$
declare s voter_sessions%rowtype;
begin
 select * into s from voter_sessions where token_hash=encode(digest(p_session_token,'sha256'),'hex') for update;
 if not found or s.used_at is not null or s.expires_at<now() then raise exception 'INVALID_OR_EXPIRED_SESSION'; end if;
 update elections set status='OPEN'
 where id=s.election_id and status='SCHEDULED' and now() between start_at and end_at;
 return query select * from submit_ballot(s.voter_id,s.election_id,p_choices,p_idempotency_key);
 update voter_sessions set used_at=now() where id=s.id;
end$$;
revoke all on function submit_voter_ballot(text,jsonb,uuid) from public;
grant execute on function submit_voter_ballot(text,jsonb,uuid) to anon,authenticated;
commit;
