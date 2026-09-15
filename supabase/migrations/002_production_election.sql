-- KCS Parent Election production setup
-- Saturday 19 September 2026, 10:30-11:30 Africa/Kinshasa (UTC+01)
begin;
create table if not exists candidate_applications(id uuid primary key default gen_random_uuid(),first_name text not null,last_name text not null,phone text not null,email text not null,parent_seniority integer not null check(parent_seniority between 0 and 50),relationship text not null check(relationship in('Father','Mother','Guardian')),position_name text not null check(position_name in('PRESIDENT','SECRETARY','TREASURER')),biography text not null,manifesto text not null,photo_url text,status text not null default 'PENDING' check(status in('PENDING','APPROVED','REJECTED')),consented_at timestamptz not null default now(),created_at timestamptz not null default now());
create table if not exists candidate_application_children(id uuid primary key default gen_random_uuid(),application_id uuid not null references candidate_applications on delete cascade,last_name text not null,middle_name text not null,first_name text not null,student_class text not null,created_at timestamptz not null default now());
alter table candidate_applications enable row level security;
alter table candidate_application_children enable row level security;
insert into elections(title,description,start_at,end_at,timezone,school_year,status,allow_abstention,show_interim_results,results_published)
select 'KCS Parent Election 2026','Official KCS Parent Committee election','2026-09-19 10:30:00+01','2026-09-19 11:30:00+01','Africa/Kinshasa','2026-2027','SCHEDULED',false,false,false
where not exists(select 1 from elections where title='KCS Parent Election 2026');
insert into positions(election_id,name,display_order)
select e.id,p.name,p.display_order from elections e cross join(values('PRESIDENT',1),('SECRETARY',2),('TREASURER',3)) as p(name,display_order)
where e.title='KCS Parent Election 2026' on conflict(election_id,name) do update set display_order=excluded.display_order;
drop view if exists published_results;
create view published_results with(security_invoker=false) as select p.election_id,p.name position,c.id candidate_id,trim(concat_ws(' ',c.first_name,c.middle_name,c.last_name)) candidate,count(bc.candidate_id)::bigint votes,rank() over(partition by p.id order by count(bc.candidate_id) desc) ranking from positions p join elections e on e.id=p.election_id join candidates c on c.position_id=p.id and c.active left join ballot_choices bc on bc.candidate_id=c.id where e.results_published group by p.election_id,p.id,p.name,c.id;
grant select on published_results to anon,authenticated;
commit;
