-- Shared property terms are entered once and copied into each new rental.
-- Historic rental particulars remain a snapshot, not a live mutable template.
begin;
create table if not exists public.bp_property_agreements (
 property_id uuid primary key references public.bp_properties(id) on delete cascade,
 details jsonb not null default '{}'::jsonb,
 history jsonb not null default '[]'::jsonb,
 updated_at timestamptz not null default now()
);
alter table public.bp_property_agreements enable row level security;
revoke all on public.bp_property_agreements from anon,authenticated;
grant select on public.bp_property_agreements to authenticated;
drop policy if exists bp_property_agreement_read on public.bp_property_agreements;
create policy bp_property_agreement_read on public.bp_property_agreements for select to authenticated using(public.bp_owns(property_id));

do $$begin
 if to_regprocedure('public.bp_action_before_agreement_defaults(text,jsonb)') is null then
  alter function public.bp_action(text,jsonb) rename to bp_action_before_agreement_defaults;
 end if;
 if to_regprocedure('public.bp_snapshot_before_agreement_defaults()') is null then
  alter function public.bp_snapshot() rename to bp_snapshot_before_agreement_defaults;
 end if;
end $$;
revoke all on function public.bp_action_before_agreement_defaults(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_before_agreement_defaults() from public,anon;
grant execute on function public.bp_snapshot_before_agreement_defaults() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare p public.bp_properties;t public.bp_tenancies;template public.bp_property_agreements;
 body jsonb;key text;result jsonb;tid uuid;new_amount integer;prior_notice_ids uuid[]:=array[]::uuid[];
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation='property_agreement' then
  select * into p from public.bp_properties where id=(args->>'propertyId')::uuid and owner_id=auth.uid() for update;
  if not found then raise exception 'Property unavailable.';end if;
  body:=coalesce(args->'details','{}');
  if jsonb_typeof(body)<>'object' then raise exception 'Check the property terms.';end if;
  foreach key in array array['landlordAddress','authority','sharedFacilities','paymentInstructions','noticeTerms','escalationTerms','otherCharges','utilities','houseRules'] loop
   if jsonb_typeof(body->key)<>'string' or length(trim(coalesce(body->>key,''))) not between 1 and 1500 then
    raise exception 'Complete the shared property terms; enter None where it does not apply.';
   end if;
  end loop;
  if length(body->>'utilities')>1000 then raise exception 'Utility instructions may use up to 1000 characters.';end if;
  select jsonb_object_agg(k,trim(body->>k)) into body from unnest(array['landlordAddress','authority','sharedFacilities','paymentInstructions','noticeTerms','escalationTerms','otherCharges','utilities','houseRules']) k;
  insert into public.bp_property_agreements(property_id,details) values(p.id,body)
   on conflict(property_id) do update set history=bp_property_agreements.history||jsonb_build_array(jsonb_build_object('details',bp_property_agreements.details,'recordedAt',bp_property_agreements.updated_at)),details=excluded.details,updated_at=now();
  return jsonb_build_object('result',p.id);
 end if;
 if operation='agreement' then
  select * into t from public.bp_tenancies where id=(args->>'tenancyId')::uuid;
  if not found or not public.bp_owns(t.property_id) then raise exception 'Rental unavailable.';end if;
  perform 1 from public.bp_properties where id=t.property_id for update;
  select * into t from public.bp_tenancies where id=t.id for update;
  if (args->>'start')::date is distinct from t.starts then raise exception 'Move-in date is fixed from tenant onboarding.';end if;
  if t.terms->>'depositCents' is not null and (args->>'depositCents')::integer is distinct from (t.terms->>'depositCents')::integer then
   raise exception 'The security deposit is fixed from tenant onboarding. Record received payments and returns separately.';
  end if;
 end if;
 if operation='rent_term' then
  select coalesce(array_agg(id),array[]::uuid[]) into prior_notice_ids from public.bp_notices where title='Dated rent change recorded';
 end if;
 result:=public.bp_action_before_agreement_defaults(operation,args);
 if operation='tenancy' then
  tid:=(result->>'result')::uuid;
  select * into t from public.bp_tenancies where id=tid;
  select * into template from public.bp_property_agreements where property_id=t.property_id;
  if found then
   body:=template.details-'utilities'-'houseRules';
   update public.bp_tenancies set record=body||record||jsonb_build_object('propertyTermsCopiedAt',template.updated_at),terms=terms||jsonb_build_object('utilities',template.details->>'utilities','houseRules',template.details->>'houseRules') where id=tid;
  end if;
 elsif operation='rent_term' then
  select * into t from public.bp_tenancies where id=(args->>'tenancyId')::uuid;
  new_amount:=(args->>'amountCents')::integer;
  update public.bp_notices set message='Room '||t.room||': new rent R '||to_char(new_amount::numeric/100,'FM9999999990.00')||' per month from '||(args->>'period')||'. Rent remains due on the 1st. Reference: '||left(trim(args->>'evidence'),1000)
   where user_id=t.tenant_id and title='Dated rent change recorded' and not(id=any(prior_notice_ids));
 end if;
 return result;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_before_agreement_defaults();
 return s||jsonb_build_object('agreementDefaultsVersion',1,'propertyAgreements',coalesce((select jsonb_agg(jsonb_build_object('propertyId',property_id,'details',details,'updatedAt',updated_at)) from public.bp_property_agreements),'[]'::jsonb));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
