-- Assign KCS election administration only to the verified institutional account.
begin;
create or replace function provision_kcs_election_admin()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare eid uuid;
begin
 if lower(new.email) <> 'kinshasachristianschool@gmail.com' then return new; end if;
 select id into eid from public.elections where title='KCS Parent Election 2026' order by created_at desc limit 1;
 if eid is null then return new; end if;
 insert into public.profiles(id,display_name) values(new.id,'KCS Election Administration') on conflict(id) do update set display_name=excluded.display_name;
 insert into public.admin_roles(user_id,election_id,role) values(new.id,eid,'SUPER_ADMIN') on conflict(user_id,election_id) do update set role=excluded.role;
 return new;
end$$;
drop trigger if exists provision_kcs_admin_after_user on auth.users;
create trigger provision_kcs_admin_after_user after insert or update of email on auth.users for each row execute function provision_kcs_election_admin();
insert into public.profiles(id,display_name)
select id,'KCS Election Administration' from auth.users where lower(email)='kinshasachristianschool@gmail.com'
on conflict(id) do update set display_name=excluded.display_name;
insert into public.admin_roles(user_id,election_id,role)
select u.id,e.id,'SUPER_ADMIN'::admin_role from auth.users u cross join lateral(select id from public.elections where title='KCS Parent Election 2026' order by created_at desc limit 1)e where lower(u.email)='kinshasachristianschool@gmail.com'
on conflict(user_id,election_id) do update set role=excluded.role;
commit;
