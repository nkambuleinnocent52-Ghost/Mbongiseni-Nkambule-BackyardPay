-- Preserve the tenant's proposed rent months when the landlord confirms receipt.
-- This adds no charge/payment and does not rewrite existing allocations/receipts.
begin;
do $$begin
 if to_regprocedure('public.bp_action_before_payment_intent(text,jsonb)') is null then
  alter function public.bp_action(text,jsonb) rename to bp_action_before_payment_intent;
 end if;
 if to_regprocedure('public.bp_snapshot_before_payment_intent()') is null then
  alter function public.bp_snapshot() rename to bp_snapshot_before_payment_intent;
 end if;
end $$;
revoke all on function public.bp_action_before_payment_intent(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_before_payment_intent() from public,anon;
grant execute on function public.bp_snapshot_before_payment_intent() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare pay public.bp_payments; owner_id uuid; proposed jsonb; requested jsonb; part jsonb;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation='review' and coalesce((args->>'confirm')::boolean,false) then
  -- Match the existing mutation lock order: user, property, then rental/payment.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
  select * into pay from public.bp_payments where id=(args->>'id')::uuid;
  if not found then raise exception 'Payment unavailable.';end if;
  select p.owner_id into owner_id from public.bp_properties p
   join public.bp_tenancies t on t.property_id=p.id where t.id=pay.tenancy_id for update of p;
  if owner_id is distinct from auth.uid() or not exists(select 1 from public.bp_profiles where id=auth.uid() and role='landlord') then
   raise exception 'Only the linked landlord can confirm this rent payment.';
  end if;
  select * into pay from public.bp_payments where id=pay.id for update;
  if pay.state<>'pending' then raise exception 'This payment has already been reviewed.';end if;
  select coalesce(jsonb_agg(jsonb_build_object('period',to_char(a.period,'YYYY-MM'),'amountCents',a.amount) order by a.period,a.amount),'[]'::jsonb)
   into proposed from public.bp_allocations a where a.payment_id=pay.id;
  if args ? 'allocations' then
   if jsonb_typeof(args->'allocations') is distinct from 'array' or jsonb_array_length(args->'allocations')>120 then
    raise exception 'Provide a valid rent-month list.';
   end if;
   for part in select value from jsonb_array_elements(args->'allocations') loop
    if jsonb_typeof(part) is distinct from 'object' or coalesce(part->>'period','') !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
     or coalesce(part->>'amountCents','') !~ '^[0-9]+$' then raise exception 'Provide a valid rent-month list.';end if;
   end loop;
   select coalesce(jsonb_agg(jsonb_build_object('period',e->>'period','amountCents',(e->>'amountCents')::integer) order by e->>'period',(e->>'amountCents')::integer),'[]'::jsonb)
    into requested from jsonb_array_elements(args->'allocations') e;
   if requested<>proposed then
    raise exception 'Confirm the tenant''s reported rent months unchanged. If they are wrong, reject with a reason and ask the tenant to submit the correction.';
   end if;
  end if;
  -- Older clients without an allocation argument confirm the saved proposal.
  args:=args||jsonb_build_object('allocations',proposed);
 end if;
 return public.bp_action_before_payment_intent(operation,args);
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
begin
 return public.bp_snapshot_before_payment_intent()||jsonb_build_object('paymentIntentVersion',1);
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
