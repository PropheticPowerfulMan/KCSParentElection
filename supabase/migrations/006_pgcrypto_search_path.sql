-- Make Supabase pgcrypto functions available to the security-definer routines.
begin;
alter function submit_ballot(uuid,uuid,jsonb,uuid) set search_path=public,extensions;
alter function review_candidate_application(uuid,text) set search_path=public,extensions;
alter function import_parent_registry(jsonb) set search_path=public,extensions;
alter function authenticate_voter(text,text) set search_path=public,extensions;
alter function submit_voter_ballot(text,jsonb,uuid) set search_path=public,extensions;
commit;
