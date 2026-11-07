-- Additive update: new rental agreements only. Never recalculate existing balances.
begin;
alter table public.bp_properties add column if not exists prorate_first boolean not null default true;
alter table public.bp_tenancies add column if not exists first_month_prorated boolean not null default false;

create or replace function public.bp_first_month_policy() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if tg_op='INSERT' then
  select prorate_first into new.first_month_prorated from public.bp_properties where id=new.property_id;
 elsif new.first_month_prorated is distinct from old.first_month_prorated then
  raise exception 'The recorded first-month billing basis cannot be rewritten. Use an evidenced charge adjustment.';
 end if;
 return new;
end $$;
revoke all on function public.bp_first_month_policy() from public,anon,authenticated;
drop trigger if exists bp_first_month_policy on public.bp_tenancies;
create trigger bp_first_month_policy before insert or update on public.bp_tenancies for each row execute function public.bp_first_month_policy();

create or replace function public.bp_rent_due(tid uuid,pr date) returns integer language sql stable security definer set search_path=public,pg_temp as $$
 select case when pr<date_trunc('month',t.starts)::date or (t.ended_on is not null and pr>date_trunc('month',t.ended_on)::date) then 0 else
 (case when t.first_month_prorated and pr=date_trunc('month',t.starts)::date then
 round(coalesce((select amount from public.bp_rent_terms where tenancy_id=t.id and period<=pr order by period desc limit 1),t.rent)::numeric
 * (((date_trunc('month',t.starts)+interval '1 month')::date-t.starts)::integer)
 / extract(day from (date_trunc('month',t.starts)+interval '1 month - 1 day')))::integer
 else coalesce((select amount from public.bp_rent_terms where tenancy_id=t.id and period<=pr order by period desc limit 1),t.rent) end)
 +coalesce((select sum((body->>'amountCents')::integer) from public.bp_case_records where tenancy_id=t.id and kind='adjustment' and body->>'period'=to_char(pr,'YYYY-MM')),0)::integer end
 from public.bp_tenancies t where t.id=tid;
$$;
revoke all on function public.bp_rent_due(uuid,date) from public,anon,authenticated;

do $$begin
 if to_regprocedure('public.bp_action_v2(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v2;end if;
 if to_regprocedure('public.bp_snapshot_v2()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v2;end if;
end $$;
revoke all on function public.bp_action_v2(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v2() from public,anon;
grant execute on function public.bp_snapshot_v2() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r jsonb;
begin
 r:=public.bp_action_v2(operation,args);
 if operation='property' and args ? 'prorateFirstMonth' then
  if jsonb_typeof(args->'prorateFirstMonth')<>'boolean' then raise exception 'Choose the first-month billing basis.';end if;
  update public.bp_properties set prorate_first=(args->>'prorateFirstMonth')::boolean where id=(r->>'result')::uuid and owner_id=auth.uid();
 end if;
 return r;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v2();
 return s||jsonb_build_object('prorationVersion',1,
 'properties',coalesce((select jsonb_agg(e||jsonb_build_object('prorateFirstMonth',p.prorate_first)) from jsonb_array_elements(s->'properties') e join public.bp_properties p on p.id=(e->>'id')::uuid),'[]'),
 'tenancies',coalesce((select jsonb_agg(e||jsonb_build_object('record',e->'record'||jsonb_build_object('firstMonthProration',case when t.first_month_prorated then 'actual_days' else 'full_month' end,'tenancyStartedOn',t.starts))) from jsonb_array_elements(s->'tenancies') e join public.bp_tenancies t on t.id=(e->>'id')::uuid),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
