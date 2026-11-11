-- Allow an actual payment made today/past to cover rent up to twelve months ahead.
-- Keep allocations linked to their stated month; do not move advance money into today's rent.
begin;
do $$
declare definition text;old_guard text;new_guard text;rent_guard text;
begin
 if to_regprocedure('public.bp_action_v2(text,jsonb)') is null then
  raise exception 'Apply the existing research, proration and date updates first.';
 end if;
 definition:=pg_get_functiondef('public.bp_action_v2(text,jsonb)'::regprocedure);
 old_guard:='pr>date_trunc(''month'',current_date)::date or public.bp_rent_due(t.id,pr)<=0';
 new_guard:='pr>(date_trunc(''month'',current_date)+interval ''12 months'')::date or public.bp_rent_due(t.id,pr)<=0';
 if position(old_guard in definition)>0 then
  definition:=replace(definition,old_guard,new_guard);
 elsif position(new_guard in definition)=0 then
  raise exception 'Existing month validation was not recognised; no change was applied.';
 end if;
 definition:=replace(definition,'Choose a charged rental month and positive allocation.','Choose a rent month within your tenancy and no more than 12 months ahead, with an amount greater than R0.');
 -- A future rent reduction must not leave more money assigned than the new charge.
 -- Only months governed by this new term are checked, ending at the next recorded term.
 rent_guard:=$guard$  if exists(
   select 1 from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id
   where x.tenancy_id=t.id and x.state='confirmed' and a.period>=pr
    and a.period<coalesce((select min(period) from public.bp_rent_terms where tenancy_id=t.id and period>pr),'infinity'::date)
   group by a.period having sum(a.amount)>(args->>'amountCents')::integer
  ) then raise exception 'This rent change is below money already confirmed for a prepaid month. Reconcile that payment before reducing the rent.';end if;
$guard$;
 if position('This rent change is below money already confirmed for a prepaid month.' in definition)=0 then
  if position('  insert into public.bp_rent_terms values(t.id,pr,' in definition)=0 then
   raise exception 'Existing rent-term validation was not recognised; no change was applied.';
  end if;
  definition:=replace(definition,'  insert into public.bp_rent_terms values(t.id,pr,',rent_guard||'  insert into public.bp_rent_terms values(t.id,pr,');
 end if;
 -- Refunded/rejected payment history remains, but must not permanently prevent handover.
 definition:=replace(definition,
  'where x.tenancy_id=t.id and a.period>date_trunc(''month'',sd)::date)',
  'where x.tenancy_id=t.id and x.state in (''pending'',''confirmed'') and a.period>date_trunc(''month'',sd)::date)');
 execute definition;
end $$;
revoke all on function public.bp_action_v2(text,jsonb) from public,anon,authenticated;
commit;
