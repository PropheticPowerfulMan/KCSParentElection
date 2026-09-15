-- Certified, privacy-safe and statistically descriptive election results
begin;
create table if not exists election_certifications(
 id uuid primary key default gen_random_uuid(),election_id uuid not null unique references elections on delete restrict,
 report_hash text not null unique check(length(report_hash)=64),certified_by uuid references auth.users,
 certified_at timestamptz not null default now(),summary jsonb not null
);
alter table election_certifications enable row level security;
create policy public_certification on election_certifications for select using(exists(select 1 from elections e where e.id=election_id and e.results_published));

create or replace function build_election_report(p_election_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare e elections%rowtype;eligible int;ballots_count int;positions_count int;actual_choices int;expected_choices int;position_row record;candidate_data jsonb;positions_data jsonb='[]'::jsonb;valid_votes int;abstentions int;top_votes int;second_votes int;leaders int;hhi numeric;effective_candidates numeric;
begin
 select * into e from elections where id=p_election_id;if not found then raise exception 'ELECTION_NOT_FOUND';end if;
 select count(*) into eligible from voters where election_id=e.id and eligible;
 select count(*) into ballots_count from ballots where election_id=e.id;
 select count(*) into positions_count from positions where election_id=e.id;
 select count(*) into actual_choices from ballot_choices where election_id=e.id;
 expected_choices=ballots_count*positions_count;
 for position_row in select * from positions where election_id=e.id order by display_order loop
  select count(*) filter(where not abstained),count(*) filter(where abstained) into valid_votes,abstentions from ballot_choices where election_id=e.id and position_id=position_row.id;
  select coalesce(max(votes),0) into top_votes from(select count(bc.candidate_id)::int votes from candidates c left join ballot_choices bc on bc.candidate_id=c.id where c.position_id=position_row.id and c.active group by c.id)x;
  select coalesce(max(votes),0) into second_votes from(select votes,dense_rank()over(order by votes desc)r from(select count(bc.candidate_id)::int votes from candidates c left join ballot_choices bc on bc.candidate_id=c.id where c.position_id=position_row.id and c.active group by c.id)y)z where r=2;
  select count(*) into leaders from(select c.id,count(bc.candidate_id)::int votes from candidates c left join ballot_choices bc on bc.candidate_id=c.id where c.position_id=position_row.id and c.active group by c.id)x where votes=top_votes;
  select coalesce(sum(power(votes::numeric/nullif(valid_votes,0),2)),0) into hhi from(select count(bc.candidate_id)::int votes from candidates c left join ballot_choices bc on bc.candidate_id=c.id where c.position_id=position_row.id and c.active group by c.id)x;
  effective_candidates=case when hhi>0 then 1/hhi else 0 end;
  select coalesce(jsonb_agg(jsonb_build_object('candidate_id',x.id,'ballot_number',x.ballot_number,'candidate',x.candidate,'votes',x.votes,'vote_share_percent',case when valid_votes>0 then round(100*x.votes::numeric/valid_votes,2) else 0 end,'rank',x.ranking,'is_winner',x.votes=top_votes and top_votes>0) order by x.votes desc,x.ballot_number),'[]'::jsonb) into candidate_data from(select c.id,c.ballot_number,trim(concat_ws(' ',c.first_name,c.middle_name,c.last_name))candidate,count(bc.candidate_id)::int votes,rank()over(order by count(bc.candidate_id) desc)::int ranking from candidates c left join ballot_choices bc on bc.candidate_id=c.id where c.position_id=position_row.id and c.active group by c.id)x;
  positions_data=positions_data||jsonb_build_array(jsonb_build_object('position_id',position_row.id,'position',position_row.name,'valid_votes',valid_votes,'abstentions',abstentions,'top_votes',top_votes,'margin_votes',greatest(top_votes-second_votes,0),'margin_percentage_points',case when valid_votes>0 then round(100*(top_votes-second_votes)::numeric/valid_votes,2) else 0 end,'tie_for_first',leaders>1 and top_votes>0,'concentration_index',round(hhi,4),'effective_number_of_candidates',round(effective_candidates,2),'candidates',candidate_data));
 end loop;
 return jsonb_build_object('election_id',e.id,'title',e.title,'school_year',e.school_year,'timezone',e.timezone,'start_at',e.start_at,'end_at',e.end_at,'status',e.status,'eligible_voters',eligible,'ballots_cast',ballots_count,'turnout_percent',case when eligible>0 then round(100*ballots_count::numeric/eligible,2) else 0 end,'remaining_voters',greatest(eligible-ballots_count,0),'positions_count',positions_count,'expected_choices',expected_choices,'recorded_choices',actual_choices,'integrity_passed',actual_choices=expected_choices,'positions',positions_data);
end$$;
revoke all on function build_election_report(uuid) from public;

create or replace function get_admin_election_summary()
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare eid uuid;report jsonb;
begin
 select ar.election_id into eid from admin_roles ar join elections e on e.id=ar.election_id where ar.user_id=auth.uid() order by e.created_at desc limit 1;
 if eid is null then raise exception 'NOT_AUTHORIZED';end if;report=build_election_report(eid);
 return report-'positions';
end$$;
revoke all on function get_admin_election_summary() from public;grant execute on function get_admin_election_summary() to authenticated;

create or replace function get_final_results_preview()
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare eid uuid;eend timestamptz;
begin
 select ar.election_id,e.end_at into eid,eend from admin_roles ar join elections e on e.id=ar.election_id where ar.user_id=auth.uid() and ar.role=any(array['SUPER_ADMIN','ELECTION_ADMIN','OBSERVER']::admin_role[]) order by e.created_at desc limit 1;
 if eid is null then raise exception 'NOT_AUTHORIZED';end if;if now()<eend then raise exception 'RESULTS_SEALED_UNTIL_CLOSE';end if;return build_election_report(eid);
end$$;
revoke all on function get_final_results_preview() from public;grant execute on function get_final_results_preview() to authenticated;

create or replace function publish_certified_results()
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare eid uuid;e elections%rowtype;report jsonb;fingerprint text;previous text;payload text;
begin
 select ar.election_id into eid from admin_roles ar join elections x on x.id=ar.election_id where ar.user_id=auth.uid() and ar.role=any(array['SUPER_ADMIN','ELECTION_ADMIN']::admin_role[]) order by x.created_at desc limit 1;
 if eid is null then raise exception 'NOT_AUTHORIZED';end if;select * into e from elections where id=eid for update;
 if now()<e.end_at then raise exception 'CANNOT_PUBLISH_BEFORE_CLOSE';end if;
 if exists(select 1 from positions p where p.election_id=eid and not exists(select 1 from candidates c where c.position_id=p.id and c.active)) then raise exception 'INCOMPLETE_CANDIDATE_LIST';end if;
 update elections set status='RESULTS_PUBLISHED',results_published=true where id=eid;
 report=build_election_report(eid);if not (report->>'integrity_passed')::boolean then raise exception 'BALLOT_INTEGRITY_CHECK_FAILED';end if;
 fingerprint=encode(digest(convert_to(report::text,'UTF8'),'sha256'),'hex');
 insert into election_certifications(election_id,report_hash,certified_by,summary) values(eid,fingerprint,auth.uid(),report);
 select entry_hash into previous from audit_logs where election_id=eid order by id desc limit 1;payload=concat_ws('|',eid::text,auth.uid()::text,'RESULTS_CERTIFIED',fingerprint,coalesce(previous,''));
 insert into audit_logs(election_id,actor_id,action,entity_type,entity_id,metadata,previous_hash,entry_hash) values(eid,auth.uid(),'RESULTS_CERTIFIED','election',eid::text,jsonb_build_object('report_hash',fingerprint),previous,encode(digest(payload,'sha256'),'hex'));
 return report||jsonb_build_object('report_hash',fingerprint,'certified_at',now());
end$$;
revoke all on function publish_certified_results() from public;grant execute on function publish_certified_results() to authenticated;

create or replace function get_official_election_results()
returns jsonb language plpgsql stable security definer set search_path=public,extensions as $$
declare eid uuid;cert election_certifications%rowtype;
begin
 select id into eid from elections where results_published order by end_at desc limit 1;if eid is null then return null;end if;
 select * into cert from election_certifications where election_id=eid;return build_election_report(eid)||jsonb_build_object('report_hash',cert.report_hash,'certified_at',cert.certified_at);
end$$;
revoke all on function get_official_election_results() from public;grant execute on function get_official_election_results() to anon,authenticated;

create or replace function prevent_certification_mutation() returns trigger language plpgsql as $$begin raise exception 'CERTIFIED_RESULTS_ARE_IMMUTABLE';end$$;
drop trigger if exists certification_immutable on election_certifications;
create trigger certification_immutable before update or delete on election_certifications for each row execute function prevent_certification_mutation();

create or replace function freeze_election_configuration() returns trigger language plpgsql as $$
declare eid uuid;opening timestamptz;
begin
 eid=case when tg_op='DELETE' then old.election_id else new.election_id end;
 select start_at into opening from elections where id=eid;
 if now()>=opening then raise exception 'ELECTION_CONFIGURATION_IS_FROZEN';end if;
 return case when tg_op='DELETE' then old else new end;
end$$;
drop trigger if exists candidates_frozen_at_opening on candidates;
create trigger candidates_frozen_at_opening before insert or update or delete on candidates for each row execute function freeze_election_configuration();
drop trigger if exists positions_frozen_at_opening on positions;
create trigger positions_frozen_at_opening before insert or update or delete on positions for each row execute function freeze_election_configuration();
commit;
