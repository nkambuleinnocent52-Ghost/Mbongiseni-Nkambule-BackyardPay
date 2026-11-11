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
