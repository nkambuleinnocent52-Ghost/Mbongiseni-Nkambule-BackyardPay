-- RESEARCH UPDATE: additive upgrade. Apply after 202610240001_backyardpay.sql.
-- Keeps existing accounts, records and Auth configuration. No sample data.
begin;
alter table public.bp_tenancies alter column tenant_id drop not null;
alter table public.bp_tenancies add column if not exists record jsonb not null default '{}';
alter table public.bp_tenancies add column if not exists ended_on date;
alter table public.bp_tenancies add column if not exists invitation text not null default ('JOIN-'||upper(replace(gen_random_uuid()::text,'-','')));
create unique index if not exists bp_tenancy_invitation on public.bp_tenancies(invitation);
alter table public.bp_payments drop constraint if exists bp_payments_state_check;
alter table public.bp_payments add constraint bp_payments_state_check check(state in ('pending','confirmed','rejected','reversed'));
alter table public.bp_payments add column if not exists payer text not null default '';
alter table public.bp_payments add column if not exists entered_by uuid references public.bp_profiles(id);
alter table public.bp_payments add column if not exists receipt_details jsonb;
alter table public.bp_payments drop constraint if exists bp_payments_method_check;
alter table public.bp_payments add constraint bp_payments_method_check check(method in ('Cash','Cash deposit','EFT','PayShap','Debit order','Other'));
alter table public.bp_payments drop constraint if exists bp_payments_check;
alter table public.bp_payments drop constraint if exists bp_payment_bank_reference;
alter table public.bp_payments add constraint bp_payment_bank_reference check(method not in ('EFT','PayShap','Cash deposit','Debit order') or length(bank_reference)>0) not valid;
create table if not exists public.bp_rent_terms(
 tenancy_id uuid not null references public.bp_tenancies(id), period date not null check(extract(day from period)=1),
 amount integer not null check(amount>0), due_day integer not null check(due_day between 1 and 28),
 evidence text not null, created_at timestamptz not null default now(), actor uuid references public.bp_profiles(id),
 primary key(tenancy_id,period)
);
create table if not exists public.bp_allocations(
 payment_id uuid not null references public.bp_payments(id),period date not null check(extract(day from period)=1),
 amount integer not null check(amount>0),primary key(payment_id,period)
);
create table if not exists public.bp_case_records(
 id uuid primary key default gen_random_uuid(),tenancy_id uuid not null references public.bp_tenancies(id),
 kind text not null check(kind in ('deposit','inspection','repair','query','case_update','adjustment','audit')),
 body jsonb not null check(jsonb_typeof(body)='object' and octet_length(body::text)<=24000),
 actor uuid not null references public.bp_profiles(id),created_at timestamptz not null default now()
);
create index if not exists bp_cases_tenancy on public.bp_case_records(tenancy_id,created_at);
-- Only new tables are seeded with existing facts. These are not new payments.
insert into public.bp_rent_terms(tenancy_id,period,amount,due_day,evidence,actor)
 select t.id,date_trunc('month',t.starts)::date,t.rent,t.due_day,'Opening terms retained from existing rental record',p.owner_id
 from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id on conflict do nothing;
insert into public.bp_allocations(payment_id,period,amount)
 select id,period,amount from public.bp_payments where entered_by is null on conflict do nothing;
insert into public.bp_case_records(id,tenancy_id,kind,body,actor)
 select md5('opening-deposit:'||t.id::text)::uuid,t.id,'deposit',jsonb_build_object('event','opening','amountCents',(t.terms->>'depositReceivedCents')::integer,'reference','Opening deposit from previous record','date',current_date,'note','Migrated summary; not a new receipt of money'),p.owner_id
 from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id
 where coalesce((t.terms->>'depositReceivedCents')::integer,0)>0 on conflict do nothing;
alter table public.bp_rent_terms enable row level security;
alter table public.bp_allocations enable row level security;
alter table public.bp_case_records enable row level security;
revoke all on public.bp_rent_terms,public.bp_allocations,public.bp_case_records from anon,authenticated;
grant select on public.bp_rent_terms,public.bp_allocations,public.bp_case_records to authenticated;
drop policy if exists bp_terms_read on public.bp_rent_terms;
create policy bp_terms_read on public.bp_rent_terms for select to authenticated using(public.bp_sees_tenancy(tenancy_id));
drop policy if exists bp_allocations_read on public.bp_allocations;
create policy bp_allocations_read on public.bp_allocations for select to authenticated using(exists(select 1 from public.bp_payments p where p.id=payment_id and public.bp_sees_tenancy(p.tenancy_id)));
drop policy if exists bp_cases_read on public.bp_case_records;
create policy bp_cases_read on public.bp_case_records for select to authenticated using(public.bp_sees_tenancy(tenancy_id));

create or replace function public.bp_rent_due(tid uuid,pr date) returns integer language sql stable security definer set search_path=public,pg_temp as $$
 select case when pr<date_trunc('month',t.starts)::date or (t.ended_on is not null and pr>date_trunc('month',t.ended_on)::date) then 0 else
 coalesce((select amount from public.bp_rent_terms where tenancy_id=t.id and period<=pr order by period desc limit 1),t.rent)
 +coalesce((select sum((body->>'amountCents')::integer) from public.bp_case_records where tenancy_id=t.id and kind='adjustment' and body->>'period'=to_char(pr,'YYYY-MM')),0)::integer end
 from public.bp_tenancies t where t.id=tid;
$$;
revoke all on function public.bp_rent_due(uuid,date) from public,anon,authenticated;
create or replace function public.bp_capture_receipt(tid uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('tenant',coalesce(a.name,t.record->>'tenantName','Not recorded'),'landlord',o.name,'landlordAddress',t.record->>'landlordAddress','address',concat_ws(', ',p.address,nullif(p.suburb,''),nullif(p.city,''),nullif(p.postal_code,'')),'property',p.name,'room',t.room::text)
 from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id join public.bp_profiles o on o.id=p.owner_id left join public.bp_profiles a on a.id=t.tenant_id where t.id=tid;
$$;
revoke all on function public.bp_capture_receipt(uuid) from public,anon,authenticated;

-- Save the previous checked command as an internal helper, never a public bypass.
do $$begin
 if to_regprocedure('public.bp_action_v1(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v1; end if;
 if to_regprocedure('public.bp_snapshot_v1()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v1; end if;
end $$;
revoke all on function public.bp_action_v1(text,jsonb) from public,anon,authenticated;
-- The legacy snapshot remains invoker/RLS filtered; it contains no privileged data.
revoke all on function public.bp_snapshot_v1() from public,anon;
grant execute on function public.bp_snapshot_v1() to authenticated;
create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v1();
 return s||jsonb_build_object('researchVersion',2,
 'tenancies',coalesce((select jsonb_agg(e||jsonb_build_object('record',t.record||jsonb_build_object('tenancyStartedOn',t.starts),'endedOn',t.ended_on,'ledgerVersion',2,'invitation',case when public.bp_owns(t.property_id) then t.invitation else null end)) from jsonb_array_elements(s->'tenancies') e join public.bp_tenancies t on t.id=(e->>'id')::uuid),'[]'),
 'payments',coalesce((select jsonb_agg(e||jsonb_build_object('payer',p.payer,'enteredBy',p.entered_by,'receiptDetails',p.receipt_details,'allocations',coalesce((select jsonb_agg(jsonb_build_object('period',to_char(a.period,'YYYY-MM'),'amountCents',a.amount)) from public.bp_allocations a where a.payment_id=p.id),'[]'))) from jsonb_array_elements(s->'payments') e join public.bp_payments p on p.id=(e->>'id')::uuid),'[]'),
 'rentTerms',coalesce((select jsonb_agg(jsonb_build_object('tenancyId',tenancy_id,'period',to_char(period,'YYYY-MM'),'amountCents',amount,'dueDay',due_day,'evidence',evidence,'createdAt',created_at)) from public.bp_rent_terms),'[]'),
 'caseRecords',coalesce((select jsonb_agg(jsonb_build_object('id',id,'tenancyId',tenancy_id,'kind',kind,'body',body,'actor',actor,'createdAt',created_at)) from public.bp_case_records),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u public.bp_profiles;p public.bp_properties;t public.bp_tenancies;pay public.bp_payments;
 rid uuid;pr date;sd date;ed date;amt integer;tot bigint;used bigint;bal bigint;part jsonb;record_body jsonb;owner boolean;ok boolean;result jsonb:='null';k text;ev text;parent public.bp_case_records;
begin
 select * into u from public.bp_profiles where id=auth.uid();if not found then raise exception 'Sign in to continue.';end if;
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,0));
 if operation in ('profile','property','deleteProperty','location','read','acknowledge') then return public.bp_action_v1(operation,args);end if;
 if operation='join_rental' then
  if u.role<>'tenant' then raise exception 'Tenant account required.';end if;
  if exists(select 1 from public.bp_tenancies where tenant_id=u.id and ended_on is null) then raise exception 'Complete the existing rental handover before joining another.';end if;
  select * into t from public.bp_tenancies where invitation=upper(trim(args->>'invitation')) and tenant_id is null and ended_on is null;
  if not found then raise exception 'Private rental invitation unavailable.';end if;
  perform 1 from public.bp_properties where id=t.property_id for update;
  select * into t from public.bp_tenancies where id=t.id for update;
  if t.tenant_id is not null or t.ended_on is not null then raise exception 'Invitation already used or rental ended.';end if;
  update public.bp_tenancies set tenant_id=u.id,invitation='USED-'||gen_random_uuid()::text where id=t.id;
  return jsonb_build_object('result',t.id);
 end if;
 if operation='tenancy' then
  select * into p from public.bp_properties where id=(args->>'propertyId')::uuid and owner_id=u.id for update;
  if not found or u.role<>'landlord' then raise exception 'Property unavailable.';end if;
  amt:=(args->>'room')::integer;sd:=(args->>'start')::date;
  if amt<1 or amt>p.rooms or sd<'2020-01-01' or sd>current_date or length(trim(coalesce(args->>'name',''))) not between 2 and 80 then raise exception 'Check tenant, room and start date.';end if;
  if exists(select 1 from public.bp_tenancies where property_id=p.id and room=amt and (ended_on is null or ended_on>=sd)) then raise exception 'Room has an overlapping tenancy. Complete handover first.';end if;
  insert into public.bp_tenancies(property_id,tenant_id,room,starts,rent,due_day,record) values(p.id,null,amt,sd,p.rent,p.due_day,jsonb_build_object('tenantName',trim(args->>'name'),'tenantPhone',left(coalesce(args->>'phone',''),30),'tenantEmail',left(coalesce(args->>'email',''),254))) returning * into t;
  insert into public.bp_rent_terms values(t.id,date_trunc('month',sd)::date,p.rent,p.due_day,'Opening agreed rental rate',now(),u.id);
  return jsonb_build_object('result',t.id);
 end if;
 if operation in ('review','allocate_credit','reverse_payment') then
  select * into pay from public.bp_payments where id=(args->>'id')::uuid;if not found then raise exception 'Payment unavailable.';end if;rid:=pay.tenancy_id;
 else rid:=(args->>'tenancyId')::uuid;end if;
 select * into t from public.bp_tenancies where id=rid;if not found then raise exception 'Rental record unavailable.';end if;
 select * into p from public.bp_properties where id=t.property_id for update;
 select * into t from public.bp_tenancies where id=rid for update;
 owner:=p.owner_id=u.id and u.role='landlord';
 if not owner and (t.tenant_id is null or t.tenant_id<>u.id) then raise exception 'You do not have access to this rental record.';end if;
 if operation='reverse_payment' then
  if not owner or pay.state<>'confirmed' or length(trim(coalesce(args->>'reason',''))) not between 3 and 1500 then raise exception 'Only the landlord can reverse a confirmed receipt. Record the actual return/reversal and its evidence.';end if;
  update public.bp_payments set state='reversed',reason=trim(args->>'reason') where id=pay.id;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','payment_reversal','paymentId',pay.id,'reference',pay.reference,'note',args->>'reason','date',current_date),u.id);
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Received payment reversed','Check the retained receipt record, reversal explanation and updated rental account.');end if;
  return jsonb_build_object('result',pay.id);
 end if;
 if operation in ('payment','review','allocate_credit') then
  if operation='payment' then
   amt:=(args->>'amountCents')::integer;sd:=(args->>'paidOn')::date;
   if amt is null or amt<=0 or sd is null or sd<'2020-01-01' or sd>current_date or length(trim(coalesce(args->>'payer',''))) not between 2 and 100 then raise exception 'Check amount, actual payer and payment date.';end if;
   if owner and coalesce((args->>'received')::boolean,false) is not true then raise exception 'Check money received before issuing a receipt.';end if;
   insert into public.bp_payments(tenancy_id,period,amount,method,reference,bank_reference,notes,paid_on,state,reviewed_at,payer,entered_by,receipt_details)
    values(t.id,date_trunc('month',sd)::date,amt,args->>'method',trim(args->>'reference'),trim(coalesce(args->>'bankReference','')),trim(coalesce(args->>'notes','')),sd,case when owner then 'confirmed' else 'pending' end,case when owner then now() else null end,trim(args->>'payer'),u.id,case when owner then public.bp_capture_receipt(t.id) else null end) returning * into pay;
   ok:=owner;
  else
   if not owner then raise exception 'Only the linked landlord can confirm or allocate payments.';end if;
   select * into pay from public.bp_payments where id=pay.id for update;
   if operation='review' then
    if pay.state<>'pending' then raise exception 'This payment has already been reviewed.';end if;
    ok:=(args->>'confirm')::boolean;if ok is null then raise exception 'Choose confirm or reject.';end if;
    if not ok then
     if length(trim(coalesce(args->>'reason',''))) not between 1 and 500 then raise exception 'Give a reason for the rejected record.';end if;
     update public.bp_payments set state='rejected',reason=trim(args->>'reason'),reviewed_at=now() where id=pay.id;
     if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Payment record rejected',trim(args->>'reason')||' This is a record decision, not a legal finding.');end if;
     return jsonb_build_object('result',null);
    end if;
    delete from public.bp_allocations where payment_id=pay.id;
   else
    if pay.state<>'confirmed' then raise exception 'Only confirmed unallocated credit can be allocated.';end if;ok:=true;
   end if;
  end if;
  if coalesce(jsonb_typeof(args->'allocations'),'')<>'array' or coalesce(jsonb_array_length(args->'allocations'),100)>120 then raise exception 'Provide a valid allocation list.';end if;
  select coalesce(sum(amount),0) into tot from public.bp_allocations where payment_id=pay.id;
  for part in select value from jsonb_array_elements(args->'allocations') loop
   if coalesce(part->>'period','') !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Use a valid rental month.';end if;
   pr:=((part->>'period')||'-01')::date;amt:=(part->>'amountCents')::integer;
   if amt is null or amt<=0 or pr<date_trunc('month',t.starts)::date or pr>date_trunc('month',current_date)::date or public.bp_rent_due(t.id,pr)<=0 then raise exception 'Choose a charged rental month and positive allocation.';end if;
   tot:=tot+amt;if tot>pay.amount then raise exception 'Allocations exceed the money received.';end if;
   if ok then
    select coalesce(sum(a.amount),0) into used from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id where x.tenancy_id=t.id and x.state='confirmed' and a.period=pr;
    if used+amt>public.bp_rent_due(t.id,pr) then raise exception 'Allocation exceeds this month’s recorded charge. Leave the remainder as credit.';end if;
   end if;
   if operation='allocate_credit' then
    insert into public.bp_allocations values(pay.id,pr,amt) on conflict(payment_id,period) do update set amount=public.bp_allocations.amount+excluded.amount;
   else insert into public.bp_allocations values(pay.id,pr,amt);end if;
  end loop;
  if ok and operation<>'allocate_credit' then
   update public.bp_payments set state='confirmed',reviewed_at=now(),receipt_details=public.bp_capture_receipt(t.id)||jsonb_build_object('issuedAllocations',coalesce((select jsonb_agg(jsonb_build_object('period',to_char(period,'YYYY-MM'),'amountCents',amount)) from public.bp_allocations where payment_id=pay.id),'[]'),'issuedCreditCents',pay.amount-tot) where id=pay.id;
  end if;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action',operation,'paymentId',pay.id,'reference',pay.reference,'note',coalesce(args->>'reason','Recorded payment/allocation')),u.id);
  if owner and t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Payment confirmed','Money received and recorded. View its allocations, credit and rental receipt.');
  elsif not owner then insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Payment awaiting reconciliation','A tenant reported a payment. Review the money received and its proposed allocations.');end if;
  result:=to_jsonb(pay.id);
 elsif operation='reminder' then
  if not owner or t.tenant_id is null then raise exception 'Only linked tenant accounts can receive in-app reminders. Share their statement separately.';end if;
  return public.bp_action_v1(operation,args);
 elsif operation='agreement' then
  if not owner then raise exception 'Only the landlord can update agreed terms.';end if;
  sd:=(args->>'start')::date;ed:=nullif(args->>'end','')::date;
  if sd is null or sd<'2020-01-01' or sd>current_date or ed<sd then raise exception 'Check rental dates.';end if;
  if coalesce(args->>'agreementType','') not in ('Month-to-month','Fixed term') or (args->>'agreementType'='Fixed term' and ed is null) or (args->>'agreementType'='Month-to-month' and ed is not null) then raise exception 'Check the rental type and planned end date.';end if;
  if (args->>'depositCents')::integer<0 or length(trim(args->>'utilities')) not between 1 and 1000 or length(trim(args->>'houseRules')) not between 1 and 2000 then raise exception 'Check the deposit, utilities and house rules.';end if;
  if exists(select 1 from public.bp_payments where tenancy_id=t.id) and sd<>t.starts then raise exception 'Start date is locked once payment history exists. Record a documented account adjustment instead.';end if;
  record_body:=coalesce(args->'details','{}');
  foreach k in array array['landlordAddress','tenantAddress','authority','dwellingDescription','sharedFacilities','paymentInstructions','noticeTerms','escalationTerms','otherCharges'] loop
   if length(trim(coalesce(record_body->>k,''))) not between 1 and 1500 then raise exception 'Complete all essential lease details; write None where genuinely not applicable.';end if;
  end loop;
  if exists(select 1 from public.bp_tenancies x where x.property_id=t.property_id and x.room=t.room and x.id<>t.id and sd<=coalesce(x.ended_on,'infinity'::date) and x.starts<=coalesce(t.ended_on,'infinity'::date)) then raise exception 'Rental dates overlap another room occupant.';end if;
  update public.bp_tenancies set starts=sd,ends=ed,acknowledged_at=null,record=record||record_body,terms=jsonb_build_object('agreementType',args->>'agreementType','depositCents',(args->>'depositCents')::integer,'depositReceivedCents',coalesce((terms->>'depositReceivedCents')::integer,0),'utilities',trim(args->>'utilities'),'houseRules',trim(args->>'houseRules'),'emergencyName',left(coalesce(args->>'emergencyName',''),80),'emergencyPhone',left(coalesce(args->>'emergencyPhone',''),20),'termsUpdatedAt',now()) where id=t.id;
  if sd<>t.starts then update public.bp_rent_terms set period=date_trunc('month',sd)::date where tenancy_id=t.id and period=date_trunc('month',t.starts)::date;end if;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','agreement','previous',t.record||t.terms,'updated',record_body||args),u.id);
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Rental details updated','Review the changed terms. Reading acknowledgement is not a signature.');end if;
 elsif operation='rent_term' then
  if not owner then raise exception 'Only the landlord can record an agreed rent change.';end if;
  pr:=((args->>'period')||'-01')::date;
  if pr<=date_trunc('month',current_date)::date or length(trim(coalesce(args->>'evidence',''))) not between 3 and 1500 then raise exception 'Use a future month and record the actual agreement/evidence.';end if;
  insert into public.bp_rent_terms values(t.id,pr,(args->>'amountCents')::integer,(args->>'dueDay')::integer,trim(args->>'evidence'),now(),u.id);
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Dated rent change recorded','Check the effective month and agreement in rental account history.');end if;
 elsif operation='close_tenancy' then
  sd:=(args->>'date')::date;
  if not owner or sd is null or sd<t.starts or sd>current_date or length(trim(coalesce(args->>'note',''))) not between 3 and 1500 then raise exception 'Record the actual handover date and agreed final-billing explanation.';end if;
  if t.ended_on is not null then raise exception 'Handover is already recorded.';end if;
  if exists(select 1 from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id where x.tenancy_id=t.id and a.period>date_trunc('month',sd)::date) then raise exception 'Later allocations exist. Reconcile the account before handover.';end if;
  update public.bp_tenancies set ended_on=sd where id=t.id;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','handover','date',sd,'note',args->>'note'),u.id);
 elsif operation='case' then
  k:=args->>'kind';record_body:=args->'body';
  if args->>'eventId' is null then raise exception 'A stable record identifier is required.';end if;
  select * into parent from public.bp_case_records where id=(args->>'eventId')::uuid;
  if found then
   if parent.tenancy_id=t.id and parent.actor=u.id and parent.kind=k and (parent.body-'receiptDetails'-'status')=(record_body-'receiptDetails'-'status') then return jsonb_build_object('result',parent.id);end if;
   raise exception 'This record identifier is already saved. Refresh before creating another record.';
  end if;
  if k not in ('deposit','inspection','repair','query','case_update','adjustment') or jsonb_typeof(record_body)<>'object' or octet_length(record_body::text)>16000 then raise exception 'Check the rental record fields.';end if;
  if k in ('deposit','inspection','adjustment') and not owner then raise exception 'Only the landlord can enter this record.';end if;
  if k='deposit' then
   ev:=record_body->>'event';amt:=(record_body->>'amountCents')::integer;sd:=(record_body->>'date')::date;
   if coalesce(ev,'') not in ('received','interest','deduction','refund') or amt is null or amt<=0 or sd is null or sd<'2020-01-01' or sd>current_date or length(trim(coalesce(record_body->>'reference',''))) not between 3 and 500 then raise exception 'Check deposit event, amount, date and evidence/reference.';end if;
   select coalesce(sum(case when c.body->>'event' in ('deduction','refund') then -(c.body->>'amountCents')::integer else (c.body->>'amountCents')::integer end),0) into bal from public.bp_case_records c where c.tenancy_id=t.id and c.kind='deposit';
   if ev in ('deduction','refund') and amt>bal then raise exception 'This exceeds the deposit and interest held.';end if;
   if ev='deduction' and (length(trim(coalesce(record_body->>'note','')))<3 or not exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='inspection' and c.body->>'stage'='Entry') or not exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='inspection' and c.body->>'stage'='Exit')) then raise exception 'Record entry/exit inspections and cost evidence before a proposed deduction. Verify the legal conditions separately.';end if;
   record_body:=record_body||jsonb_build_object('receiptDetails',public.bp_capture_receipt(t.id));
  elsif k='inspection' then
   sd:=(record_body->>'date')::date;
   if coalesce(record_body->>'stage','') not in ('Entry','Exit') or sd is null or sd<t.starts-31 or sd>current_date or length(trim(coalesce(record_body->>'condition',''))) not between 3 and 5000 or length(trim(coalesce(record_body->>'participants',''))) not between 3 and 500 then raise exception 'Record stage, actual date, participants and defects/condition.';end if;
  elsif k='adjustment' then
   amt:=(record_body->>'amountCents')::integer;pr:=((record_body->>'period')||'-01')::date;
   if amt is null or amt=0 or length(trim(coalesce(record_body->>'reason',''))) not between 3 and 1500 or pr<date_trunc('month',t.starts)::date or pr>date_trunc('month',current_date)::date or (t.ended_on is not null and pr>date_trunc('month',t.ended_on)::date) then raise exception 'Use a charged month, nonzero adjustment and documented reason/evidence.';end if;
   select coalesce(sum(a.amount),0) into used from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id where x.tenancy_id=t.id and x.state='confirmed' and a.period=pr;
   if public.bp_rent_due(t.id,pr)+amt<used then raise exception 'Adjustment would reduce the charge below confirmed allocations. Reconcile received funds first.';end if;
  elsif k='case_update' then
   select * into parent from public.bp_case_records where id=(record_body->>'parentId')::uuid and tenancy_id=t.id and kind in ('repair','query');
   if not found or length(trim(coalesce(record_body->>'message',''))) not between 3 and 3000 or (not owner and coalesce(record_body->>'status','')<>'comment') or (owner and record_body->>'status' not in ('open','in_progress','resolved','comment')) then raise exception 'Only the landlord may change case status; both parties can add a message.';end if;
  else
   if length(trim(coalesce(record_body->>'description',''))) not between 3 and 3000 then raise exception 'Describe the repair or account query.';end if;
   record_body:=record_body||jsonb_build_object('status','open');
  end if;
  insert into public.bp_case_records(id,tenancy_id,kind,body,actor) values((args->>'eventId')::uuid,t.id,k,record_body,u.id) returning id into rid;result:=to_jsonb(rid);
  if owner and t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Rental record updated','A '||k||' record was added to your tenancy. Review the details.');
  elsif not owner then insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Rental record update','Your tenant added a repair/account query message.');end if;
 else raise exception 'Unknown operation.';end if;
 return jsonb_build_object('result',result);
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

-- Existing occupants can claim only the private invitation generated for that
-- tenancy; knowing a property code and occupied room is not sufficient.
create or replace function public.bp_on_signup() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare m jsonb:=new.raw_user_meta_data;p public.bp_properties;t public.bp_tenancies;r integer;join_code text:=upper(trim(m->>'code'));
begin
 if coalesce(m->>'role','') not in ('landlord','tenant') then raise exception 'Choose a valid role.';end if;
 insert into public.bp_profiles values(new.id,m->>'role',trim(m->>'name'),new.email,trim(m->>'phone'));
 if m->>'role'='tenant' then
  select * into t from public.bp_tenancies where invitation=join_code;
  if found then
   select * into p from public.bp_properties where id=t.property_id for update;
   select * into t from public.bp_tenancies where id=t.id for update;
   if t.tenant_id is not null or t.ended_on is not null or trim(m->>'room')<>t.room::text then raise exception 'Invitation unavailable or room does not match.';end if;
   update public.bp_tenancies set tenant_id=new.id,invitation='USED-'||gen_random_uuid()::text where id=t.id;
  else
   select * into p from public.bp_properties where public.bp_properties.code=join_code for update;
   if not found or coalesce(m->>'room','') !~ '^[1-9][0-9]{0,2}$' then raise exception 'Ask your landlord for a valid code and room.';end if;
   r:=(m->>'room')::integer;
   if r>p.rooms or exists(select 1 from public.bp_tenancies where property_id=p.id and room=r and (ended_on is null or ended_on>=current_date)) then raise exception 'Room unavailable. For an existing rental ask for its private invitation.';end if;
   insert into public.bp_tenancies(property_id,tenant_id,room,starts,rent,due_day) values(p.id,new.id,r,current_date,p.rent,p.due_day) returning * into t;
   insert into public.bp_rent_terms values(t.id,date_trunc('month',current_date)::date,p.rent,p.due_day,'Opening rental terms',now(),p.owner_id);
  end if;
  insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Tenant account connected',trim(m->>'name')||' is linked to room '||t.room||'.');
 end if;
 return new;
end $$;
revoke all on function public.bp_on_signup() from public,anon,authenticated;
commit;


begin;
-- Private supporting files. Uploaded evidence is not bank verification or a signature.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('bp-documents','bp-documents',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
create table if not exists public.bp_documents(
 id uuid primary key default gen_random_uuid(),tenancy_id uuid not null references public.bp_tenancies(id),
 object_path text not null unique,title text not null check(length(title) between 3 and 150),
 category text not null check(category in ('Lease','Inspection','Payment evidence','Deposit evidence','Other')),
 uploaded_by uuid not null references public.bp_profiles(id),created_at timestamptz not null default now()
);
alter table public.bp_documents enable row level security;
revoke all on public.bp_documents from anon,authenticated;
grant select on public.bp_documents to authenticated;
drop policy if exists document_scope on public.bp_documents;
create policy document_scope on public.bp_documents for select to authenticated using(public.bp_sees_tenancy(tenancy_id));
drop policy if exists bp_file_read on storage.objects;
create policy bp_file_read on storage.objects for select to authenticated using(bucket_id='bp-documents' and exists(select 1 from public.bp_documents d where d.object_path=name and public.bp_sees_tenancy(d.tenancy_id)));
drop policy if exists bp_file_upload on storage.objects;
create policy bp_file_upload on storage.objects for insert to authenticated with check(bucket_id='bp-documents' and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' and public.bp_sees_tenancy(split_part(name,'/',1)::uuid));
-- Only orphaned files owned by their uploader can be cleaned up. Registered evidence cannot be overwritten/deleted by the app.
drop policy if exists bp_file_cleanup on storage.objects;
create policy bp_file_cleanup on storage.objects for delete to authenticated using(bucket_id='bp-documents' and owner_id=auth.uid()::text and not exists(select 1 from public.bp_documents d where d.object_path=name));
create or replace function public.bp_register_document(tid uuid,path text,label text,category_name text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare rid uuid;
begin
 if not public.bp_sees_tenancy(tid) then raise exception 'Rental access required.';end if;
 if split_part(path,'/',1)<>tid::text or path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' or not exists(select 1 from storage.objects o where o.bucket_id='bp-documents' and o.name=path and o.owner_id=auth.uid()::text) then raise exception 'Upload your file to this rental first.';end if;
 insert into public.bp_documents(tenancy_id,object_path,title,category,uploaded_by) values(tid,path,trim(label),category_name,auth.uid()) returning id into rid;
 return rid;
end $$;
revoke all on function public.bp_register_document(uuid,text,text,text) from public,anon;
grant execute on function public.bp_register_document(uuid,text,text,text) to authenticated;

commit;
