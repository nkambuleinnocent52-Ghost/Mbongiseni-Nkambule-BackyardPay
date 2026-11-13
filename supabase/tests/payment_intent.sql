\set ON_ERROR_STOP on
begin;
set local timezone='Africa/Johannesburg';
insert into auth.users values
 ('a0100000-0000-0000-0000-000000000001','intent-owner@test.invalid','{"role":"landlord","name":"Intent owner","phone":"0711111101"}'),
 ('a0100000-0000-0000-0000-000000000002','intent-outsider@test.invalid','{"role":"landlord","name":"Other owner","phone":"0711111102"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','a0100000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"name":"Intent rooms","address":"1 Example Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":4,"rentCents":150000,"dueDay":1,"securityDepositCents":200000,"prorateFirstMonth":true}');
select id as prop from public.bp_properties where name='Intent rooms' \gset
select public.bp_action('tenancy',jsonb_build_object('propertyId',:'prop','name','Intent tenant','room',1,'start',date_trunc('month',current_date)::date));
select id as tid,invitation as invite from public.bp_tenancies where property_id=:'prop' and room=1 \gset
select set_config('test.intent_tid',:'tid',true),set_config('test.intent_now',to_char(current_date,'YYYY-MM'),true),set_config('test.intent_next',to_char(current_date+interval '1 month','YYYY-MM'),true);
-- A documented charge correction gives this month's actual rent of R1200.
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','adjustment','body',jsonb_build_object('period',to_char(current_date,'YYYY-MM'),'amountCents',-30000,'reason','Documented first rent correction for this test')));
reset role;
insert into auth.users values('a0100000-0000-0000-0000-000000000003','intent-tenant@test.invalid',jsonb_build_object('role','tenant','name','Intent tenant','phone','0711111103','code',:'invite'));
set local role authenticated;
select set_config('request.jwt.claim.sub','a0100000-0000-0000-0000-000000000003',true);
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',200000,'method','EFT','bankReference','INTENT-BANK-2000','reference','INTENT-2000','payer','Intent tenant','paidOn',current_date,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.intent_now'),'amountCents',120000),jsonb_build_object('period',current_setting('test.intent_next'),'amountCents',80000))));
select id as pay from public.bp_payments where reference='INTENT-2000' \gset
select set_config('test.intent_pay',:'pay',true);
select set_config('request.jwt.claim.sub','a0100000-0000-0000-0000-000000000001',true);
do $$begin
 begin
  perform public.bp_action('review',jsonb_build_object('id',current_setting('test.intent_pay'),'confirm',true,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.intent_now'),'amountCents',100000),jsonb_build_object('period',current_setting('test.intent_next'),'amountCents',100000))));
  raise exception 'FAIL: landlord silently changed tenant months';
 exception when raise_exception then assert sqlerrm like 'Confirm the tenant%';end;
 assert (select state='pending' from public.bp_payments where id=current_setting('test.intent_pay')::uuid),'Failed confirmation did not change pending state';
 assert (select amount=80000 from public.bp_allocations where payment_id=current_setting('test.intent_pay')::uuid and period=(current_setting('test.intent_next')||'-01')::date),'Failed confirmation did not change next month proposal';
end $$;
select set_config('request.jwt.claim.sub','a0100000-0000-0000-0000-000000000002',true);
do $$begin
 begin perform public.bp_action('review',jsonb_build_object('id',current_setting('test.intent_pay'),'confirm',true));raise exception 'FAIL: outsider confirmed payment';exception when raise_exception then assert sqlerrm like 'Only the linked landlord%';end;
end $$;
select set_config('request.jwt.claim.sub','a0100000-0000-0000-0000-000000000001',true);
-- Different row order describes the same intent and is accepted.
select public.bp_action('review',jsonb_build_object('id',:'pay','confirm',true,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.intent_next'),'amountCents',80000),jsonb_build_object('period',current_setting('test.intent_now'),'amountCents',120000))));
do $$declare next_paid integer;current_paid integer;begin
 select sum(a.amount) filter(where a.period=(current_setting('test.intent_next')||'-01')::date),sum(a.amount) filter(where a.period=(current_setting('test.intent_now')||'-01')::date) into next_paid,current_paid
 from public.bp_allocations a join public.bp_payments p on p.id=a.payment_id where p.tenancy_id=current_setting('test.intent_tid')::uuid and p.state='confirmed';
 assert current_paid=120000,'Current R1200 rent covered exactly';
 assert (select rent from public.bp_tenancies where id=current_setting('test.intent_tid')::uuid)-next_paid=70000,'R800 goes towards next R1500 rent, leaving R700';
 assert (select receipt_details->'issuedAllocations' @> jsonb_build_array(jsonb_build_object('period',current_setting('test.intent_next'),'amountCents',80000)) from public.bp_payments where id=current_setting('test.intent_pay')::uuid),'Receipt retains advance allocation';
 assert (public.bp_snapshot()->>'paymentIntentVersion')::integer=1,'Capability reported';
 assert not has_function_privilege('authenticated','public.bp_action_before_payment_intent(text,jsonb)','execute'),'No authenticated helper bypass';
 assert not has_function_privilege('anon','public.bp_action_before_payment_intent(text,jsonb)','execute'),'No anonymous helper bypass';
end $$;
-- Empty proposals remain unallocated; omission confirms them without inventing months.
select set_config('request.jwt.claim.sub','a0100000-0000-0000-0000-000000000003',true);
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',30000,'method','Cash','reference','INTENT-CREDIT','payer','Intent tenant','paidOn',current_date,'allocations','[]'::jsonb));
select id as credit from public.bp_payments where reference='INTENT-CREDIT' \gset
select set_config('test.intent_credit',:'credit',true);
select set_config('request.jwt.claim.sub','a0100000-0000-0000-0000-000000000001',true);
do $$begin
 begin perform public.bp_action('review',jsonb_build_object('id',current_setting('test.intent_credit'),'confirm',true,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.intent_next'),'amountCents',30000))));raise exception 'FAIL: landlord invented month for unallocated proposal';exception when raise_exception then assert sqlerrm like 'Confirm the tenant%';end;
end $$;
select public.bp_action('review',jsonb_build_object('id',:'credit','confirm',true));
do $$begin
 assert (select state='confirmed' and (receipt_details->>'issuedCreditCents')::integer=30000 from public.bp_payments where id=current_setting('test.intent_credit')::uuid),'Legacy omission confirms original unallocated credit';
 assert not exists(select 1 from public.bp_allocations where payment_id=current_setting('test.intent_credit')::uuid),'No month invented';
end $$;
-- Owner-entered actual cash still permits the specified months; this is a new record, not tenant review.
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',10000,'method','Cash','reference','INTENT-OWNER-CASH','payer','Intent tenant','paidOn',current_date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.intent_next'),'amountCents',10000))));
rollback;
\echo 'Payment intent checks passed: original month proposals preserved, order-independent confirmation, owner-only receipt check, R2000/R1200/R800/R700 example, empty credit and existing receipt history.'
