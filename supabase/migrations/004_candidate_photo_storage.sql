-- Private candidate photo storage
begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('candidate-photos','candidate-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists candidate_photo_upload on storage.objects;
create policy candidate_photo_upload on storage.objects for insert to anon,authenticated with check(bucket_id='candidate-photos' and exists(select 1 from candidate_applications a where a.id=(storage.foldername(name))[1]::uuid and a.status='PENDING'));
drop policy if exists candidate_photo_admin_read on storage.objects;
create policy candidate_photo_admin_read on storage.objects for select to authenticated using(bucket_id='candidate-photos' and exists(select 1 from candidate_applications a where a.id=(storage.foldername(name))[1]::uuid and is_admin(a.election_id,array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[])));
create or replace function set_candidate_application_photo(p_application_id uuid,p_path text) returns void language plpgsql security definer set search_path=public as $$
begin
 if p_path not like p_application_id::text||'/%' then raise exception 'INVALID_PHOTO_PATH';end if;
 update candidate_applications set photo_url=p_path where id=p_application_id and status='PENDING' and created_at>now()-interval '30 minutes';
 if not found then raise exception 'APPLICATION_NOT_AVAILABLE';end if;
end$$;
revoke all on function set_candidate_application_photo(uuid,text) from public;
grant execute on function set_candidate_application_photo(uuid,text) to anon,authenticated;
commit;
