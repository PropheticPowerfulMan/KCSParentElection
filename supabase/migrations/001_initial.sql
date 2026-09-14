create extension if not exists pgcrypto;
create type election_status as enum ('DRAFT','SCHEDULED','OPEN','CLOSED','RESULTS_PUBLISHED','ARCHIVED');
create type admin_role as enum ('SUPER_ADMIN','ELECTION_ADMIN','OBSERVER');
create table elections(id uuid primary key default gen_random_uuid(),title text not null,description text,start_at timestamptz not null,end_at timestamptz not null check(end_at>start_at),timezone text not null default 'Africa/Kinshasa',school_year text,status election_status not null default 'DRAFT',allow_abstention boolean not null default false,show_interim_results boolean not null default false,results_published boolean not null default false,created_at timestamptz not null default now());
create table profiles(id uuid primary key references auth.users on delete cascade,display_name text not null,created_at timestamptz default now());
create table admin_roles(user_id uuid references profiles on delete cascade,election_id uuid references elections on delete cascade,role admin_role not null,primary key(user_id,election_id));
create table positions(id uuid primary key default gen_random_uuid(),election_id uuid not null references elections on delete cascade,name text not null check(name in('PRESIDENT','SECRETARY','TREASURER')),display_order smallint not null check(display_order between 1 and 3),unique(election_id,name),unique(election_id,display_order));
create table candidates(id uuid primary key default gen_random_uuid(),election_id uuid not null references elections on delete cascade,position_id uuid not null references positions on delete restrict,first_name text not null,last_name text not null,middle_name text,photo_url text,biography text,manifesto text,ballot_number integer not null check(ballot_number>0),active boolean not null default true,created_at timestamptz default now(),unique(election_id,ballot_number),unique(id,position_id,election_id));
create table voters(id uuid primary key default gen_random_uuid(),election_id uuid not null references elections on delete cascade,voter_code text not null,pin_hash text not null,first_name text not null,last_name text not null,middle_name text,phone text,email text,student_name text not null,student_id text not null,student_class text not null,relationship text check(relationship in('Father','Mother','Guardian')),eligible boolean not null default true,has_voted boolean not null default false,voted_at timestamptz,failed_attempts integer not null default 0,locked_until timestamptz,created_at timestamptz default now(),updated_at timestamptz default now(),unique(election_id,voter_code),unique(election_id,student_id),unique(id,election_id));
create table ballots(id uuid primary key default gen_random_uuid(),election_id uuid not null references elections on delete cascade,anonymous_ballot_token uuid not null default gen_random_uuid() unique,idempotency_key uuid not null unique,submitted_at timestamptz not null default now(),unique(id,election_id));
create table ballot_choices(ballot_id uuid not null,election_id uuid not null,position_id uuid not null,candidate_id uuid,abstained boolean not null default false,primary key(ballot_id,position_id),foreign key(ballot_id,election_id) references ballots(id,election_id) on delete restrict,foreign key(candidate_id,position_id,election_id) references candidates(id,position_id,election_id) on delete restrict,check((candidate_id is null)<> (not abstained)));
create table audit_logs(id bigint generated always as identity primary key,election_id uuid references elections,actor_id uuid references auth.users,action text not null,entity_type text,entity_id text,metadata jsonb not null default '{}',previous_hash text,entry_hash text not null,created_at timestamptz not null default now());
create table login_attempts(id bigint generated always as identity primary key,voter_code text not null,ip_hash text,successful boolean not null,created_at timestamptz default now());
create index on voters(election_id,student_class);create index on voters(election_id,has_voted);create index on ballots(election_id,submitted_at);create index on ballot_choices(election_id,position_id,candidate_id);
alter table elections enable row level security;alter table positions enable row level security;alter table candidates enable row level security;alter table voters enable row level security;alter table ballots enable row level security;alter table ballot_choices enable row level security;alter table audit_logs enable row level security;alter table admin_roles enable row level security;
create function is_admin(eid uuid,allowed admin_role[]) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from admin_roles where user_id=auth.uid() and election_id=eid and role=any(allowed))$$;
create policy public_published_election on elections for select using(results_published or is_admin(id,array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[]));
create policy public_candidates on candidates for select using(active);
create policy public_positions on positions for select using(true);
create policy admins_voters on voters for select using(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[]));
create policy managers_voters_write on voters for all using(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[])) with check(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]));
create policy managers_candidates on candidates for all using(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[])) with check(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]));
create policy admins_audit on audit_logs for select using(is_admin(election_id,array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[]));
revoke all on ballots,ballot_choices from anon,authenticated;revoke update,delete on ballots,ballot_choices from anon,authenticated;
create or replace function submit_ballot(p_voter_id uuid,p_election_id uuid,p_choices jsonb,p_idempotency_key uuid) returns table(confirmation_code text,submitted_at timestamptz) language plpgsql security definer set search_path=public as $$declare v voterS%rowtype;e elections%rowtype;b uuid;item jsonb;expected int;begin
 select * into v from voters where id=p_voter_id and election_id=p_election_id for update;
 if not found or not v.eligible then raise exception 'VOTER_NOT_ELIGIBLE';end if;
 if v.has_voted then raise exception 'ALREADY_VOTED';end if;
 select * into e from elections where id=p_election_id for share;
 if e.status<>'OPEN' or now()<e.start_at or now()>e.end_at then raise exception 'ELECTION_NOT_OPEN';end if;
 select count(*) into expected from positions where election_id=p_election_id;
 if jsonb_array_length(p_choices)<>expected then raise exception 'INCOMPLETE_BALLOT';end if;
 insert into ballots(election_id,idempotency_key) values(p_election_id,p_idempotency_key) returning id into b;
 for item in select * from jsonb_array_elements(p_choices) loop
  if coalesce((item->>'abstained')::boolean,false) and not e.allow_abstention then raise exception 'ABSTENTION_DISABLED';end if;
  insert into ballot_choices(ballot_id,election_id,position_id,candidate_id,abstained)
  select b,p_election_id,p.id,case when coalesce((item->>'abstained')::boolean,false) then null else (item->>'candidate_id')::uuid end,coalesce((item->>'abstained')::boolean,false)
  from positions p where p.id=(item->>'position_id')::uuid and p.election_id=p_election_id;
  if not found then raise exception 'INVALID_POSITION';end if;
 end loop;
 if (select count(*) from ballot_choices where ballot_id=b)<>expected then raise exception 'INVALID_BALLOT';end if;
 update voters set has_voted=true,voted_at=now(),pin_hash=crypt(gen_random_uuid()::text,gen_salt('bf')),updated_at=now() where id=v.id;
 return query select upper(substr(replace(b::text,'-',''),1,12)),x.submitted_at from ballots x where x.id=b;end$$;
revoke all on function submit_ballot(uuid,uuid,jsonb,uuid) from public;grant execute on function submit_ballot(uuid,uuid,jsonb,uuid) to service_role;
create view published_results with(security_invoker=true) as select p.election_id,p.name position,c.id candidate_id,c.first_name||' '||c.last_name candidate,count(bc.candidate_id) votes,rank() over(partition by p.id order by count(bc.candidate_id) desc) ranking from positions p join elections e on e.id=p.election_id join candidates c on c.position_id=p.id left join ballot_choices bc on bc.candidate_id=c.id where e.results_published group by p.election_id,p.id,p.name,c.id;
create or replace function prevent_ballot_mutation() returns trigger language plpgsql as $$begin raise exception 'SUBMITTED_BALLOTS_ARE_IMMUTABLE';end$$;
create trigger ballots_immutable before update or delete on ballots for each row execute function prevent_ballot_mutation();create trigger choices_immutable before update or delete on ballot_choices for each row execute function prevent_ballot_mutation();