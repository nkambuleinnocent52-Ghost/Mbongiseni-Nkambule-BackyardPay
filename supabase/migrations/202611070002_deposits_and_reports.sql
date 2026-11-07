-- Apply after the Research and Proration updates. No existing financial history is rewritten.
begin;
alter table public.bp_properties add column if not exists security_deposit integer check(security_deposit>=0);
alter table public.bp_documents add column if not exists case_id uuid references public.bp_case_records(id);

create or replace function public.bp_security_deposit_policy() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare amount integer;
begin
 select security_deposit into amount from public.bp_properties where id=new.property_id;
 if amount is null then raise exception 'Ask the landlord to specify the property security deposit first (0 if none).';end if;
 new.terms:=coalesce(new.terms,'{}')||jsonb_build_object('depositCents',amount,'depositReceivedCents',0);
 new.record:=coalesce(new.record,'{}')||jsonb_build_object('depositDueOn',new.starts,'depositBasis','Property deposit agreed at onboarding');
 return new;
end $$;
revoke all on function public.bp_security_deposit_policy() from public,anon,authenticated;
drop trigger if exists bp_security_deposit_policy on public.bp_tenancies;
create trigger bp_security_deposit_policy before insert on public.bp_tenancies for each row execute function public.bp_security_deposit_policy();

do $$begin
 if to_regprocedure('public.bp_action_v3(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v3;end if;
 if to_regprocedure('public.bp_snapshot_v3()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v3;end if;
end $$;
revoke all on function public.bp_action_v3(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v3() from public,anon;
grant execute on function public.bp_snapshot_v3() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r jsonb;b jsonb;d date;tid uuid;
begin
 if operation='property' and args ? 'securityDepositCents' then
  if coalesce(jsonb_typeof(args->'securityDepositCents'),'')<>'number' or (args->>'securityDepositCents')::integer<0 then raise exception 'Specify a non-negative security deposit, or 0 if none.';end if;
 end if;
 if operation='case' and args->>'kind' in ('repair','query') then
  b:=args->'body';d:=(b->>'incidentDate')::date;
  if coalesce(b->>'category','') not in ('Water / plumbing','Gate / shared facilities','Electrical / safety','Structure / damp','Noise / nuisance','Damage inside my room','Account / deposit query','Other')
  or coalesce(b->>'urgency','') not in ('Routine','Urgent','Immediate danger')
  or coalesce(b->>'cause','') not in ('Unknown','Wear / deterioration suspected','I or my household caused it','Third party suspected','Other')
  or length(trim(coalesce(b->>'location',''))) not between 3 and 250
  or length(coalesce(b->>'accessAvailability',''))>500 or d is null or d<'2020-01-01' or d>current_date then raise exception 'Record category, urgency, date, location and what you know about the cause.';end if;
  -- Ignore attempts to turn a factual report into a financial decision.
  if b ?| array['liability','deductionCents','chargeCents','bankVerified'] then raise exception 'A report does not assign liability or deduct money.';end if;
 end if;
 r:=public.bp_action_v3(operation,args);
 if operation='property' and args ? 'securityDepositCents' then
  update public.bp_properties set security_deposit=(args->>'securityDepositCents')::integer where id=(r->>'result')::uuid and owner_id=auth.uid();
 end if;
 return r;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v3();
 return s||jsonb_build_object('depositReportsVersion',1,'properties',coalesce((select jsonb_agg(e||jsonb_build_object('securityDepositCents',p.security_deposit)) from jsonb_array_elements(s->'properties') e join public.bp_properties p on p.id=(e->>'id')::uuid),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;

create or replace function public.bp_register_case_document(tid uuid,path text,label text,category_name text,report_id uuid) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare rid uuid;
begin
 if not public.bp_sees_tenancy(tid) or not exists(select 1 from public.bp_case_records where id=report_id and tenancy_id=tid and kind in ('repair','query')) then raise exception 'Report unavailable for this rental.';end if;
 rid:=public.bp_register_document(tid,path,label,category_name);
 update public.bp_documents set case_id=report_id where id=rid;
 return rid;
end $$;
revoke all on function public.bp_register_case_document(uuid,text,text,text,uuid) from public,anon;
grant execute on function public.bp_register_case_document(uuid,text,text,text,uuid) to authenticated;
commit;
