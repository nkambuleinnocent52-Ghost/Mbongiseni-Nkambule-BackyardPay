\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Reminder rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Reminder tenant','room',24,'start',(now() at time zone 'Africa/Johannesburg')::date-20));
select id as tid,invitation as invite from public.bp_tenancies where room=24 \gset
select set_config('test.reminder_tid',:'tid',true);
reset role;
insert into auth.users values('b1000000-0000-0000-0000-000000000001','reminder-tenant@test.invalid',jsonb_build_object('name','Reminder tenant','role','tenant','phone','0712222222','code',:'invite'));
insert into auth.users values('b1000000-0000-0000-0000-000000000002','reminder-other@test.invalid','{"name":"Other landlord","role":"landlord","phone":"0713333333"}');
-- Control the date privately, without giving clients a fake-clock API.
update public.bp_tenancies set record=record||jsonb_build_object('depositDueOn',(now() at time zone 'Africa/Johannesburg')::date-9) where id=:'tid';
delete from public.bp_notices where deposit_tenancy_id=:'tid';
select public.bp_generate_deposit_reminders('b1000000-0000-0000-0000-000000000001',(now() at time zone 'Africa/Johannesburg')::date);
do $$begin
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid),'No warning before day 10';
end $$;
update public.bp_tenancies set record=record||jsonb_build_object('depositDueOn',(now() at time zone 'Africa/Johannesburg')::date-10) where id=:'tid';
select public.bp_generate_deposit_reminders('b1000000-0000-0000-0000-000000000002',(now() at time zone 'Africa/Johannesburg')::date);
do $$begin assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid),'Other landlord scope cannot trigger another property';end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
do $$declare s jsonb;begin
 s:=public.bp_snapshot();assert (s->>'depositRemindersVersion')::integer=1;
 assert (s->>'depositPaymentReportsVersion')::integer=1,'The outer reminder snapshot keeps the deposit report snapshot';
 assert jsonb_typeof(s->'depositReminderScheduler')='boolean';
 assert (select count(*)=1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid and deposit_reminder_kind='payment');
 assert (select message like '%R 2000.00%' from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid);
 begin perform public.bp_generate_deposit_reminders(null,current_date+100);raise exception 'FAIL: public global generator';exception when insufficient_privilege then null;end;
 begin perform public.bp_run_deposit_reminders();raise exception 'FAIL: public scheduled worker';exception when insufficient_privilege then null;end;
 begin perform public.bp_action('deposit_deadline',jsonb_build_object('tenancyId',current_setting('test.reminder_tid'),'date',current_date+10,'note','Tenant cannot self-defer'));raise exception 'FAIL: tenant changed deadline';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_check_deposit_reminders();
reset role;
do $$begin
 assert (select count(*)=2 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid),'One notice each for landlord and tenant, no refresh duplicates';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','b2000000-0000-0000-0000-000000000001','amountCents',100000,'paidOn',current_date,'method','Cash','reference','REMINDER-PARTIAL'));
select public.bp_check_deposit_reminders();
reset role;
do $$begin
 assert (select message like '%R 1000.00 to pay or report%' and message like '%Do not pay that reported amount again.%' from public.bp_notices where user_id='b1000000-0000-0000-0000-000000000001' and deposit_tenancy_id=current_setting('test.reminder_tid')::uuid and deposit_reminder_kind='payment');
 assert (select count(*)=1 from public.bp_notices where user_id='70000000-0000-0000-0000-000000000001' and deposit_tenancy_id=current_setting('test.reminder_tid')::uuid and deposit_reminder_kind='review');
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','b2000000-0000-0000-0000-000000000002','amountCents',100000,'paidOn',current_date,'method','Cash','reference','REMINDER-REST'));
select public.bp_check_deposit_reminders();
reset role;
do $$begin
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid and deposit_reminder_kind='payment' and not read),'Fully reported deposit should not keep asking tenant to pay again';
 assert (select count(*)=1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid and deposit_reminder_kind='review' and not read);
 assert not exists(select 1 from public.bp_case_records where tenancy_id=current_setting('test.reminder_tid')::uuid and kind='deposit'),'Reports are not receipts';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_review','{"id":"b2000000-0000-0000-0000-000000000001","confirm":true}');
select public.bp_action('deposit_review','{"id":"b2000000-0000-0000-0000-000000000002","confirm":true}');
select public.bp_check_deposit_reminders();
reset role;
do $$begin assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid')::uuid and not read),'Actual paid deposit resolves all reminder warnings';end $$;
-- Zero and unspecified deposits never generate payment warnings, even when old.
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Reminder rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":0}');
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','No deposit tenant','room',23,'start',current_date-20));
select id as zero_tid from public.bp_tenancies where room=23 \gset
select set_config('test.zero_deposit_tid',:'zero_tid',true);
reset role;
select public.bp_generate_deposit_reminders(null,current_date);
do $$begin assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.zero_deposit_tid')::uuid),'No deposit required means no reminder';end $$;
update public.bp_tenancies set terms=terms-'depositCents' where id=:'zero_tid';
select public.bp_generate_deposit_reminders(null,current_date);
do $$begin assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.zero_deposit_tid')::uuid),'An unspecified old deposit must not be invented';end $$;
-- A later agreement must prevent a ten-day warning based on the move-in date.
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Reminder rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Deferred tenant','room',25,'start',current_date-20));
select id as tid2 from public.bp_tenancies where room=25 \gset
select set_config('test.reminder_tid2',:'tid2',true);
select public.bp_action('deposit_deadline',jsonb_build_object('tenancyId',:'tid2','date',current_date+5,'note','Both parties agreed deposit instalment deadline'));
select public.bp_check_deposit_reminders();
reset role;
do $$begin
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid2')::uuid and not read),'Deferred deadline resolves premature reminders';
 assert (select record->>'depositDueNote'='Both parties agreed deposit instalment deadline' from public.bp_tenancies where id=current_setting('test.reminder_tid2')::uuid);
end $$;
update public.bp_tenancies set ended_on=current_date where id=:'tid2';
select public.bp_generate_deposit_reminders(null,current_date+100);
do $$begin
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.reminder_tid2')::uuid and not read),'Ended rental has no deposit reminder';
 assert not (select prosecdef from pg_proc where oid='public.bp_snapshot()'::regprocedure),'Snapshot must remain security invoker';
 assert not has_function_privilege('authenticated','public.bp_generate_deposit_reminders(uuid,date)','EXECUTE');
 assert not has_function_privilege('anon','public.bp_check_deposit_reminders()','EXECUTE');
 assert not has_function_privilege('authenticated','public.bp_run_deposit_reminders()','EXECUTE');
end $$;
rollback;
\echo 'Deposit reminder checks passed: day 9/10 boundary, SAST, scoped snapshots and private worker, once-only notices, pending review vs pay-again, receipts resolve warnings, agreed deferral and actual handover.'
