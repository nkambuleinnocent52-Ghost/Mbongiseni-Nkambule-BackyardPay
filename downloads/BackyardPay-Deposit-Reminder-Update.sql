-- South African rental dates must not be rejected during the UTC / SAST date gap.
begin;
do $$begin
 if to_regprocedure('public.bp_action_v5(text,jsonb)') is null then
  alter function public.bp_action(text,jsonb) rename to bp_action_v5;
 end if;
end $$;
revoke all on function public.bp_action_v5(text,jsonb) from public,anon,authenticated;
create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare paid date;amount integer;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation='payment' then
  begin amount:=(args->>'amountCents')::integer;exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Enter a valid payment amount in rand.';end;
  if amount is null or amount<=0 then raise exception 'Enter a payment amount greater than R0.';end if;
  if length(trim(coalesce(args->>'payer',''))) not between 2 and 100 then raise exception 'Enter the name of the person who paid (2–100 characters).';end if;
  begin paid:=(args->>'paidOn')::date;exception when invalid_datetime_format or datetime_field_overflow then raise exception 'Choose a valid payment date.';end;
  if paid is null or paid<'2020-01-01' then raise exception 'Choose a valid payment date from 2020 onwards.';end if;
  if paid>current_date then raise exception 'The payment date is in the future. Choose today or the day you actually paid (South African time).';end if;
 end if;
 return public.bp_action_v5(operation,args);
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;
alter function public.bp_snapshot() set timezone='Africa/Johannesburg';
commit;
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
-- Tenant deposit reports await landlord review; only confirmation records funds held.
begin;
create table if not exists public.bp_deposit_payment_reports(
 id uuid primary key,
 tenancy_id uuid not null references public.bp_tenancies(id),
 reported_by uuid not null references public.bp_profiles(id),
 amount integer not null check(amount>0),
 paid_on date not null,
 method text not null check(method in ('Cash','Cash deposit','EFT','PayShap','Debit order','Other')),
 reference text not null check(length(reference) between 3 and 100),
 bank_reference text not null default '',
 payer text not null check(length(payer) between 2 and 100),
 notes text not null default '' check(length(notes)<=1500),
 state text not null default 'pending' check(state in ('pending','confirmed','rejected')),
 reason text not null default '',
 submitted_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references public.bp_profiles(id),
 unique(tenancy_id,reference),
 check(method not in ('Cash deposit','EFT','PayShap','Debit order') or length(bank_reference) between 3 and 150)
);
create unique index if not exists bp_deposit_report_bank_payment on public.bp_deposit_payment_reports(tenancy_id,paid_on,method,bank_reference,amount) where bank_reference<>'' and state in ('pending','confirmed');
alter table public.bp_deposit_payment_reports enable row level security;
revoke all on public.bp_deposit_payment_reports from anon,authenticated;
grant select on public.bp_deposit_payment_reports to authenticated;
drop policy if exists bp_deposit_payment_reports_read on public.bp_deposit_payment_reports;
create policy bp_deposit_payment_reports_read on public.bp_deposit_payment_reports for select to authenticated using(public.bp_sees_tenancy(tenancy_id));

do $$begin
 if to_regprocedure('public.bp_action_v6(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v6;end if;
 if to_regprocedure('public.bp_snapshot_v5()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v5;end if;
end $$;
revoke all on function public.bp_action_v6(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v5() from public,anon;
grant execute on function public.bp_snapshot_v5() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare u public.bp_profiles;t public.bp_tenancies;p public.bp_properties;report public.bp_deposit_payment_reports;
 rid uuid;tid uuid;amount_cents integer;paid date;method_name text;record_ref text;bank_ref text;payer_name text;report_notes text;decision boolean;why text;received bigint;pending bigint;
begin
 if operation not in ('deposit_report','deposit_review') then return public.bp_action_v6(operation,args);end if;
 select * into u from public.bp_profiles where id=auth.uid();
 if not found then raise exception 'Sign in to continue.';end if;
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,0));
 if operation='deposit_report' then tid:=(args->>'tenancyId')::uuid;
 else
  select * into report from public.bp_deposit_payment_reports where id=(args->>'id')::uuid;
  if not found then raise exception 'Deposit payment report unavailable.';end if;
  tid:=report.tenancy_id;
 end if;
 select * into t from public.bp_tenancies where id=tid;
 select * into p from public.bp_properties where id=t.property_id for update;
 if not found then raise exception 'Rental unavailable.';end if;
 select * into t from public.bp_tenancies where id=tid for update;
 if operation='deposit_report' then
  if u.role<>'tenant' or t.tenant_id is distinct from u.id then raise exception 'Only the linked tenant can report this deposit payment.';end if;
  rid:=(args->>'eventId')::uuid;amount_cents:=(args->>'amountCents')::integer;paid:=(args->>'paidOn')::date;
  method_name:=args->>'method';record_ref:=trim(coalesce(args->>'reference',''));bank_ref:=trim(coalesce(args->>'bankReference',''));
  payer_name:=trim(coalesce(nullif(args->>'payer',''),u.name));report_notes:=trim(coalesce(args->>'notes',''));
  if rid is null or amount_cents is null or amount_cents<=0 or paid is null or paid<'2020-01-01' or paid>current_date
   or coalesce(method_name,'') not in ('Cash','Cash deposit','EFT','PayShap','Debit order','Other')
   or length(record_ref) not between 3 and 100 or length(payer_name) not between 2 and 100 or length(report_notes)>1500 or length(bank_ref)>150 then
   raise exception 'Check the deposit amount, date, payment method and payer.';
  end if;
  if method_name in ('Cash deposit','EFT','PayShap','Debit order') and length(bank_ref)<3 then raise exception 'Enter the bank payment reference from your banking app or deposit slip.';end if;
  select * into report from public.bp_deposit_payment_reports where id=rid;
  if found then
   if report.tenancy_id=t.id and report.reported_by=u.id and report.amount=amount_cents and report.paid_on=paid and report.method=method_name and report.reference=record_ref and report.bank_reference=bank_ref and report.payer=payer_name and report.notes=report_notes then return jsonb_build_object('result',report.id);end if;
   raise exception 'This payment report number is already in use. Refresh before trying again.';
  end if;
  if bank_ref<>'' and (exists(select 1 from public.bp_deposit_payment_reports d where d.tenancy_id=t.id and d.paid_on=paid and d.method=method_name and d.bank_reference=bank_ref and d.amount=amount_cents and d.state in ('pending','confirmed'))
   or exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='deposit' and c.body->>'event'='received' and c.body->>'reference'=bank_ref and (c.body->>'date')::date=paid and (c.body->>'amountCents')::integer=amount_cents)) then raise exception 'This bank deposit payment has already been reported or recorded.';end if;
  select coalesce(sum((body->>'amountCents')::integer),0) into received from public.bp_case_records where tenancy_id=t.id and kind='deposit' and body->>'event' in ('received','opening');
  select coalesce(sum(d.amount),0) into pending from public.bp_deposit_payment_reports d where d.tenancy_id=t.id and d.state='pending';
  if amount_cents>coalesce((t.terms->>'depositCents')::integer,0)-received-pending then raise exception 'This is more than the deposit still due after payments already received or waiting for review.';end if;
  if exists(select 1 from public.bp_deposit_payment_reports where tenancy_id=t.id and reference=record_ref) then raise exception 'This deposit payment reference has already been reported.';end if;
  insert into public.bp_deposit_payment_reports(id,tenancy_id,reported_by,amount,paid_on,method,reference,bank_reference,payer,notes)
   values(rid,t.id,u.id,amount_cents,paid,method_name,record_ref,bank_ref,payer_name,report_notes);
  insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Deposit payment awaiting review',u.name||' reported R '||to_char(amount_cents::numeric/100,'FM9999999990.00')||' towards the security deposit for room '||t.room||'. Check the money received before confirming.');
  return jsonb_build_object('result',rid);
 else
  if u.role<>'landlord' or p.owner_id<>u.id then raise exception 'Only the landlord can confirm or reject a deposit payment.';end if;
  select * into report from public.bp_deposit_payment_reports where id=report.id for update;
  if coalesce(jsonb_typeof(args->'confirm'),'')<>'boolean' then raise exception 'Choose whether to confirm or reject this deposit payment.';end if;
  decision:=(args->>'confirm')::boolean;why:=trim(coalesce(args->>'reason',''));
  if not decision and length(why) not between 3 and 1500 then raise exception 'Explain why the deposit payment could not be confirmed.';end if;
  if report.state<>'pending' then
   if (decision and report.state='confirmed') or (not decision and report.state='rejected' and report.reason=why) then return jsonb_build_object('result',report.id);end if;
   raise exception 'This deposit payment has already been reviewed. Refresh its details.';
  end if;
  if decision then
   if report.bank_reference<>'' and exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='deposit' and c.id<>report.id and c.body->>'event'='received' and c.body->>'reference'=report.bank_reference and (c.body->>'date')::date=report.paid_on and (c.body->>'amountCents')::integer=report.amount) then
    raise exception 'This bank deposit payment is already recorded as received. Reject this report as already recorded instead of confirming it again.';
   end if;
   -- Same event id on the actual ledger prevents a repeated confirmation counting twice.
   perform public.bp_action_v6('deposit_update',jsonb_build_object('tenancyId',t.id,'eventId',report.id,'body',jsonb_build_object(
    'event','received','amountCents',report.amount,'date',report.paid_on,'reference',case when report.bank_reference<>'' then report.bank_reference else report.reference end,
    'method',report.method,'payer',report.payer,'note','Tenant deposit payment confirmed by landlord. '||report.notes)));
  end if;
  update public.bp_deposit_payment_reports set state=case when decision then 'confirmed' else 'rejected' end,reason=case when decision then '' else why end,reviewed_at=now(),reviewed_by=u.id where id=report.id;
  if not decision then insert into public.bp_notices(user_id,title,message) values(report.reported_by,'Deposit payment needs attention',why);end if;
  return jsonb_build_object('result',report.id);
 end if;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v5();
 return s||jsonb_build_object('depositPaymentReportsVersion',1,'depositPaymentReports',coalesce((select jsonb_agg(jsonb_build_object(
  'id',id,'tenancyId',tenancy_id,'amountCents',amount,'paidOn',paid_on,'method',method,'reference',reference,'bankReference',bank_reference,'payer',payer,'notes',notes,'state',state,'reason',reason,'submittedAt',submitted_at,'reviewedAt',reviewed_at) order by submitted_at,id)
  from public.bp_deposit_payment_reports),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
-- A 10-day application reminder, not a statutory grace period or enforcement action.
begin;
alter table public.bp_notices add column if not exists deposit_tenancy_id uuid references public.bp_tenancies(id);
alter table public.bp_notices add column if not exists deposit_due_on date;
alter table public.bp_notices add column if not exists deposit_reminder_kind text check(deposit_reminder_kind in ('payment','review'));
create unique index if not exists bp_deposit_reminder_once on public.bp_notices(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null;

-- Private worker: the scheduled job processes all rentals; the authenticated
-- wrapper supplies only its caller's scope. A caller cannot choose another user/date.
create or replace function public.bp_generate_deposit_reminders(scope_user uuid,as_of date) returns integer
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare row record;due date;required_amount bigint;received_amount bigint;pending_amount bigint;outstanding_amount bigint;unreported_amount bigint;created integer:=0;affected integer;tenant_text text;owner_text text;
begin
 for row in select t.id,t.tenant_id,t.starts,t.ended_on,t.terms,t.record,t.room,p.owner_id,p.name as property_name
  from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id
  where scope_user is null or p.owner_id=scope_user or t.tenant_id=scope_user
  order by p.id,t.id for update of p,t loop
  due:=row.starts;
  begin if nullif(row.record->>'depositDueOn','') is not null then due:=(row.record->>'depositDueOn')::date;end if;
  exception when invalid_datetime_format or datetime_field_overflow then due:=row.starts;end;
  if not isfinite(due) then due:=row.starts;end if;
  required_amount:=coalesce((row.terms->>'depositCents')::integer,0);
  select coalesce(sum((body->>'amountCents')::integer),0) into received_amount from public.bp_case_records where tenancy_id=row.id and kind='deposit' and body->>'event' in ('received','opening');
  select coalesce(sum(amount),0) into pending_amount from public.bp_deposit_payment_reports where tenancy_id=row.id and state='pending';
  outstanding_amount:=greatest(0,required_amount-received_amount);
  unreported_amount:=greatest(0,outstanding_amount-pending_amount);
  -- Old warnings become read when paid, covered by a report, returned, or rescheduled.
  update public.bp_notices set read=true where deposit_tenancy_id=row.id and not read and (
   row.ended_on is not null or required_amount<=0 or outstanding_amount=0 or deposit_due_on is distinct from due or as_of<due+10
   or (deposit_reminder_kind='payment' and unreported_amount=0)
   or (deposit_reminder_kind='review' and pending_amount=0));
  if row.ended_on is not null or required_amount<=0 or outstanding_amount=0 or as_of<due+10 then continue;end if;
  if unreported_amount>0 then
   tenant_text:='Your security deposit record still shows R '||to_char(unreported_amount::numeric/100,'FM9999999990.00')||' to pay or report for room '||row.room||'. The agreed due date was '||due||', at least 10 days ago. If you already paid, report the payment or contact your landlord.';
   if pending_amount>0 then tenant_text:=tenant_text||' R '||to_char(least(pending_amount,outstanding_amount)::numeric/100,'FM9999999990.00')||' has already been reported and is waiting for your landlord to check. Do not pay that reported amount again.';end if;
   if row.tenant_id is not null then
    insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
     values(row.tenant_id,'Security deposit still outstanding',tenant_text,row.id,due,'payment')
     on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
    get diagnostics affected=row_count;created:=created+affected;
    update public.bp_notices set message=tenant_text where user_id=row.tenant_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='payment';
   end if;
   owner_text:='Room '||row.room||' at '||row.property_name||' still has R '||to_char(unreported_amount::numeric/100,'FM9999999990.00')||' of the security deposit to pay or report. The agreed due date was '||due||', at least 10 days ago. Check any money already received before following up.';
   insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
    values(row.owner_id,'Security deposit follow-up',owner_text,row.id,due,'payment')
    on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
   get diagnostics affected=row_count;created:=created+affected;
   update public.bp_notices set message=owner_text where user_id=row.owner_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='payment';
  end if;
  if pending_amount>0 then
   owner_text:='A security deposit payment of R '||to_char(least(pending_amount,outstanding_amount)::numeric/100,'FM9999999990.00')||' for room '||row.room||' at '||row.property_name||' is waiting for your confirmation. The agreed deposit due date was at least 10 days ago. Check the cash or bank payment; do not ask the tenant to pay the reported amount again.';
   insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
    values(row.owner_id,'Check reported deposit payment',owner_text,row.id,due,'review')
    on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
   get diagnostics affected=row_count;created:=created+affected;
   update public.bp_notices set message=owner_text where user_id=row.owner_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='review';
  end if;
 end loop;
 return created;
end $$;
revoke all on function public.bp_generate_deposit_reminders(uuid,date) from public,anon,authenticated;

create or replace function public.bp_check_deposit_reminders() returns integer
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.bp_profiles where id=auth.uid()) then raise exception 'Sign in to check your deposit reminders.';end if;
 return public.bp_generate_deposit_reminders(auth.uid(),current_date);
end $$;
revoke all on function public.bp_check_deposit_reminders() from public,anon;
grant execute on function public.bp_check_deposit_reminders() to authenticated;

create or replace function public.bp_run_deposit_reminders() returns integer
language sql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
 select public.bp_generate_deposit_reminders(null,current_date);
$$;
revoke all on function public.bp_run_deposit_reminders() from public,anon,authenticated;

create or replace function public.bp_deposit_reminder_scheduler_enabled() returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare enabled boolean;
begin
 if to_regclass('cron.job') is null then return false;end if;
 execute 'select exists(select 1 from cron.job where jobname=$1 and active and schedule=$2 and command=$3)'
  into enabled using 'backyardpay-deposit-reminders','0 6 * * *','select public.bp_run_deposit_reminders();';
 return coalesce(enabled,false);
end $$;
revoke all on function public.bp_deposit_reminder_scheduler_enabled() from public,anon;
grant execute on function public.bp_deposit_reminder_scheduler_enabled() to authenticated;

-- Supabase pg_cron uses UTC: 06:00 UTC is 08:00 South African time.
-- A stock PostgreSQL test database may not provide this optional extension.
do $$begin
 if not exists(select 1 from pg_extension where extname='pg_cron') and exists(select 1 from pg_available_extensions where name='pg_cron') then
  begin create extension if not exists pg_cron;
  exception when insufficient_privilege or object_not_in_prerequisite_state or feature_not_supported or undefined_file or raise_exception then
   raise notice 'Deposit reminders installed, but pg_cron could not be enabled: %. Enable Cron in Supabase to send scheduled reminders while the app is closed.',sqlerrm;
  end;
 end if;
 if to_regclass('cron.job') is not null then
  begin
   execute 'select cron.schedule($1,$2,$3)' using 'backyardpay-deposit-reminders','0 6 * * *','select public.bp_run_deposit_reminders();';
  exception when insufficient_privilege or undefined_function then
   raise notice 'Deposit reminders installed, but the daily job could not be scheduled: %. Enable/configure Cron in Supabase.',sqlerrm;
  end;
 else
  raise notice 'Deposit reminders installed. Cron is not active: reminders will be checked on signed-in app refresh until Supabase Cron is enabled and the update is run again.';
 end if;
end $$;

do $$begin
 if to_regprocedure('public.bp_action_v7(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v7;end if;
 if to_regprocedure('public.bp_snapshot_v6()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v6;end if;
end $$;
revoke all on function public.bp_action_v7(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v6() from public,anon;
grant execute on function public.bp_snapshot_v6() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare t public.bp_tenancies;p public.bp_properties;due date;note text;r jsonb;
begin
 if operation='deposit_deadline' then
  if not exists(select 1 from public.bp_profiles where id=auth.uid() and role='landlord') then raise exception 'Only the landlord can record the agreed deposit due date.';end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
  select * into t from public.bp_tenancies where id=(args->>'tenancyId')::uuid;
  select * into p from public.bp_properties where id=t.property_id and owner_id=auth.uid() for update;
  if not found then raise exception 'Rental unavailable.';end if;
  select * into t from public.bp_tenancies where id=t.id for update;
  begin due:=(args->>'date')::date;exception when invalid_datetime_format or datetime_field_overflow then raise exception 'Enter a valid agreed deposit due date.';end;
  note:=trim(coalesce(args->>'note',''));
  if due is null or not isfinite(due) or due<'2020-01-01' or due>'2100-12-31' or length(note) not between 3 and 1500 then raise exception 'Record the actual agreed due date and a short agreement/payment-plan explanation.';end if;
  if t.record->>'depositDueOn'=due::text and t.record->>'depositDueNote'=note then return jsonb_build_object('result',t.id);end if;
  update public.bp_tenancies set record=record||jsonb_build_object('depositDueOn',due,'depositDueNote',note) where id=t.id;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','deposit_deadline','date',due,'note',note),auth.uid());
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Deposit due date updated','Your agreed security deposit due date is '||due||'. '||note);end if;
  r:=jsonb_build_object('result',t.id);
 else r:=public.bp_action_v7(operation,args);
 end if;
 -- The client fetches a new snapshot in a separate RPC after a command.
 -- Do not lock all owner properties while this action still holds one property.
 return r;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

-- The snapshot remains SECURITY INVOKER; do not bypass RLS on its original reads.
create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 perform public.bp_check_deposit_reminders();
 s:=public.bp_snapshot_v6();
 return s||jsonb_build_object('depositRemindersVersion',1,'depositReminderScheduler',public.bp_deposit_reminder_scheduler_enabled());
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;

-- After Run, true means the daily background job is configured and active.
select public.bp_deposit_reminder_scheduler_enabled() as daily_background_reminders_active;
