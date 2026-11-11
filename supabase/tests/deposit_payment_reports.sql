\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Deposit reporting rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Deposit reporter','room',27,'start',(now() at time zone 'Africa/Johannesburg')::date));
select id as tid,invitation as invite from public.bp_tenancies where room=27 \gset
select set_config('test.deposit_report_tid',:'tid',true);
reset role;
insert into auth.users values('a1000000-0000-0000-0000-000000000001','deposit-report@test.invalid',jsonb_build_object('name','Deposit reporter','role','tenant','phone','0712222222','code',:'invite'));
insert into auth.users values('a1000000-0000-0000-0000-000000000002','deposit-stranger@test.invalid','{"name":"Other landlord","role":"landlord","phone":"0713333333"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','a2000000-0000-0000-0000-000000000001','amountCents',50000,'paidOn',(now() at time zone 'Africa/Johannesburg')::date,'method','EFT','reference','DEPOSIT-REPORT-1','bankReference','BANK-PAYMENT-1'));
-- Stable request replay must not create another report or notification.
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','a2000000-0000-0000-0000-000000000001','amountCents',50000,'paidOn',(now() at time zone 'Africa/Johannesburg')::date,'method','EFT','reference','DEPOSIT-REPORT-1','bankReference','BANK-PAYMENT-1'));
do $$declare s jsonb;begin
 s:=public.bp_snapshot();assert (s->>'depositPaymentReportsVersion')::integer=1;
 assert jsonb_array_length(s->'depositPaymentReports')=1;
 assert (s->'depositPaymentReports'->0->>'state')='pending';
 assert not exists(select 1 from public.bp_case_records where tenancy_id=current_setting('test.deposit_report_tid')::uuid and kind='deposit'),'Pending deposit report is not money held';
 assert not exists(select 1 from public.bp_payments where tenancy_id=current_setting('test.deposit_report_tid')::uuid),'Deposit reports must not become rent payments';
 begin perform public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000001","confirm":true}');raise exception 'FAIL: tenant self confirmed';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('deposit_report',jsonb_build_object('tenancyId',current_setting('test.deposit_report_tid'),'eventId',gen_random_uuid(),'amountCents',50000,'paidOn',current_date,'method','EFT','reference','MISSING-BANK'));raise exception 'FAIL: missing bank reference';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('deposit_report',jsonb_build_object('tenancyId',current_setting('test.deposit_report_tid'),'eventId',gen_random_uuid(),'amountCents',160000,'paidOn',current_date,'method','Cash','reference','TOO-MUCH'));raise exception 'FAIL: pending plus report exceeds deposit';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('deposit_report',jsonb_build_object('tenancyId',current_setting('test.deposit_report_tid'),'eventId',gen_random_uuid(),'amountCents',1000,'paidOn',(now() at time zone 'Africa/Johannesburg')::date+1,'method','Cash','reference','FUTURE-PAYMENT'));raise exception 'FAIL: future deposit payment';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('deposit_report',jsonb_build_object('tenancyId',current_setting('test.deposit_report_tid'),'eventId',gen_random_uuid(),'amountCents',50000,'paidOn',(now() at time zone 'Africa/Johannesburg')::date,'method','EFT','reference','DUPLICATE-BANK','bankReference','BANK-PAYMENT-1'));raise exception 'FAIL: duplicate bank transfer';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000002',true);
do $$begin
 assert jsonb_array_length(public.bp_snapshot()->'depositPaymentReports')=0,'Other owners cannot see these reports';
 begin perform public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000001","confirm":true}');raise exception 'FAIL: other owner confirmed';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
do $$begin
 assert (select count(*)=1 from public.bp_notices where user_id='70000000-0000-0000-0000-000000000001' and title='Deposit payment awaiting review');
end $$;
select public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000001","confirm":true}');
select public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000001","confirm":true}');
do $$begin
 assert (select count(*)=1 from public.bp_case_records where tenancy_id=current_setting('test.deposit_report_tid')::uuid and kind='deposit' and body->>'event'='received');
 assert (select (body->>'amountCents')::integer=50000 and body->>'reference'='BANK-PAYMENT-1' from public.bp_case_records where id='a2000000-0000-0000-0000-000000000001');
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
-- Owner manually records a reported EFT before reviewing it. There is still
-- enough deposit due, so a duplicate-transaction guard (not just the cap) is needed.
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','a2000000-0000-0000-0000-000000000004','amountCents',50000,'paidOn',(now() at time zone 'Africa/Johannesburg')::date,'method','EFT','reference','DEPOSIT-REPORT-MANUAL','bankReference','BANK-MANUAL-1'));
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_update',jsonb_build_object('tenancyId',:'tid','eventId','a3000000-0000-0000-0000-000000000001','body',jsonb_build_object('event','received','amountCents',50000,'date',(now() at time zone 'Africa/Johannesburg')::date,'method','EFT','reference','BANK-MANUAL-1')));
do $$begin
 begin perform public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000004","confirm":true}');raise exception 'FAIL: manual bank receipt counted again';exception when raise_exception then assert sqlerrm like 'This bank deposit payment is already recorded as received.%';end;
 assert (select state='pending' from public.bp_deposit_payment_reports where id='a2000000-0000-0000-0000-000000000004');
 assert (select count(*)=1 from public.bp_case_records where tenancy_id=current_setting('test.deposit_report_tid')::uuid and kind='deposit' and body->>'reference'='BANK-MANUAL-1');
 assert (select sum((body->>'amountCents')::integer)=100000 from public.bp_case_records where tenancy_id=current_setting('test.deposit_report_tid')::uuid and kind='deposit' and body->>'event'='received');
end $$;
select public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000004","confirm":false,"reason":"Already recorded as received."}');
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','a2000000-0000-0000-0000-000000000002','amountCents',100000,'paidOn',current_date,'method','Cash','reference','DEPOSIT-REPORT-2'));
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
-- An unrelated manual receipt leaves too little still due. Failed review is atomic.
select public.bp_action('deposit_update',jsonb_build_object('tenancyId',:'tid','eventId','a3000000-0000-0000-0000-000000000002','body',jsonb_build_object('event','received','amountCents',10000,'date',(now() at time zone 'Africa/Johannesburg')::date,'method','Cash','reference','MANUAL-CASH-1')));
do $$begin
 begin perform public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000002","confirm":true}');raise exception 'FAIL: review exceeded deposit now due';exception when raise_exception then assert sqlerrm='Amount exceeds the agreed deposit still due.';end;
 assert (select state='pending' from public.bp_deposit_payment_reports where id='a2000000-0000-0000-0000-000000000002');
 assert not exists(select 1 from public.bp_case_records where id='a2000000-0000-0000-0000-000000000002');
 assert (select sum((body->>'amountCents')::integer)=110000 from public.bp_case_records where tenancy_id=current_setting('test.deposit_report_tid')::uuid and kind='deposit' and body->>'event'='received');
 begin perform public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000002","confirm":false}');raise exception 'FAIL: rejection without reason';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000002","confirm":false,"reason":"Cash payment not received; please check with me."}');
select public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000002","confirm":false,"reason":"Cash payment not received; please check with me."}');
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','a2000000-0000-0000-0000-000000000003','amountCents',90000,'paidOn',current_date,'method','Cash','reference','DEPOSIT-REPORT-3'));
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_review','{"id":"a2000000-0000-0000-0000-000000000003","confirm":true}');
reset role;
do $$begin
 assert (select sum((body->>'amountCents')::integer)=200000 from public.bp_case_records where tenancy_id=current_setting('test.deposit_report_tid')::uuid and kind='deposit' and body->>'event'='received');
 assert (select count(*)=2 from public.bp_notices where user_id='a1000000-0000-0000-0000-000000000001' and title='Deposit payment needs attention');
 assert not exists(select 1 from public.bp_payments where tenancy_id=current_setting('test.deposit_report_tid')::uuid),'Deposit never reduces rent';
 assert not has_table_privilege('authenticated','public.bp_deposit_payment_reports','INSERT');
 assert not has_table_privilege('authenticated','public.bp_deposit_payment_reports','UPDATE');
end $$;
rollback;
\echo 'Deposit reports passed: tenant pending report, owner review, partial payments, cap, rejection/resubmission, replay safety, manual-receipt interleaving and atomic review failures, notifications, bank reference, RLS and rent separation.'
