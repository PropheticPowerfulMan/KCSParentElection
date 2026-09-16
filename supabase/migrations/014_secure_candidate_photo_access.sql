-- Restore the intended private candidate-photo workflow without exposing the bucket.
begin;

create or replace function can_upload_candidate_photo(p_application_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from candidate_applications
    where id=p_application_id
      and status='PENDING'
      and photo_url is null
      and created_at>now()-interval '30 minutes'
  )
$$;
revoke all on function can_upload_candidate_photo(uuid) from public;
grant execute on function can_upload_candidate_photo(uuid) to anon,authenticated;

create or replace function can_read_candidate_photo(p_application_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from candidate_applications
    where id=p_application_id
      and is_admin(
        election_id,
        array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[]
      )
  )
$$;
revoke all on function can_read_candidate_photo(uuid) from public;
grant execute on function can_read_candidate_photo(uuid) to authenticated;

drop policy if exists candidate_photo_upload on storage.objects;
create policy candidate_photo_upload on storage.objects
for insert to anon,authenticated
with check(
  bucket_id='candidate-photos'
  and can_upload_candidate_photo((storage.foldername(name))[1]::uuid)
);

drop policy if exists candidate_photo_admin_read on storage.objects;
create policy candidate_photo_admin_read on storage.objects
for select to authenticated
using(
  bucket_id='candidate-photos'
  and can_read_candidate_photo((storage.foldername(name))[1]::uuid)
);

commit;