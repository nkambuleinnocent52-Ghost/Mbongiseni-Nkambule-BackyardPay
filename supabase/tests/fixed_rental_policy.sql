\set ON_ERROR_STOP on
begin;
set local timezone='Africa/Johannesburg';
do $$declare t public.bp_tenancies;begin
 select * into t from public.bp_tenancies where id='c1000000-0000-0000-0000-000000000001';
 assert t.due_day=1 and t.record->>'depositDeadlinePolicy'='move_in_plus_10';
 assert (t.record->>'depositDueOn')::date=t.starts+10,'Existing unpaid default moves to ten-day initial payment deadline';
 assert (t.record->>'rentDuePolicyFrom')::date=(date_trunc('month',current_date)+interval '1 month')::date;
 assert (select due_day=7 and amount=150000 from public.bp_rent_terms where tenancy_id=t.id and period=date_trunc('month',t.starts)::date),'Historical charged-month due dates and amount retained';
 assert (select due_day=1 and amount=150000 from public.bp_rent_terms where tenancy_id=t.id and period=(date_trunc('month',current_date)+interval '1 month')::date),'Next month gets first-day policy with same amount';
 assert (select due_day=1 and amount=190000 from public.bp_rent_terms where tenancy_id=t.id and period=(date_trunc('month',current_date)+interval '2 months')::date),'Future agreed rate retained';
 assert public.bp_rent_due(t.id,date_trunc('month',current_date)::date)=150000;
 assert (select amount=50000 and state='confirmed' and receipt_details='{"historical":"unchanged"}'::jsonb from public.bp_payments where id='c2000000-0000-0000-0000-000000000001'),'Existing receipt unchanged';
 assert (select record->>'depositDeadlinePolicy'='legacy_agreed' and (record->>'depositDueOn')::date=starts+30 from public.bp_tenancies where id='c1000000-0000-0000-0000-000000000002'),'Actual old agreed deadline retained';
 assert (select not record ? 'depositDeadlinePolicy' from public.bp_tenancies where id='c1000000-0000-0000-0000-000000000003'),'Paid deposit history not rewritten';
 assert (select due_day=7 and not record ? 'rentDuePolicyFrom' from public.bp_tenancies where id='c1000000-0000-0000-0000-000000000004'),'Ended rental history not rewritten';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Fixed rules","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":17,"securityDepositCents":200000}');
do $$begin assert (select due_day=1 from public.bp_properties where id='70000000-0000-0000-0000-000000000002');end $$;
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','New policy tenant','room',19,'start',current_date-10));
select id as tid,invitation as invite from public.bp_tenancies where room=19 \gset
select set_config('test.fixed_tid',:'tid',true);
reset role;
insert into auth.users values('c3000000-0000-0000-0000-000000000001','fixed-policy-tenant@test.invalid',jsonb_build_object('name','New policy tenant','role','tenant','phone','0712222222','code',:'invite'));
do $$declare t public.bp_tenancies;begin
 select * into t from public.bp_tenancies where id=current_setting('test.fixed_tid')::uuid;
 assert t.due_day=1;
 assert (t.record->>'depositDueOn')::date=t.starts+10 and t.record->>'depositDeadlinePolicy'='move_in_plus_10';
 assert (select due_day=1 from public.bp_rent_terms where tenancy_id=t.id and period=date_trunc('month',t.starts)::date),'Opening monthly terms use day1';
 assert public.bp_rent_due(t.id,date_trunc('month',t.starts)::date)=round(150000::numeric*(((date_trunc('month',t.starts)+interval '1 month')::date-t.starts)::integer)/extract(day from (date_trunc('month',t.starts)+interval '1 month - 1 day')))::integer,'First-month proration preserved';
 -- Prevent metadata injected via a raw agreement call from escaping the fixed deadline.
 update public.bp_tenancies set record=record||jsonb_build_object('depositDeadlinePolicy','legacy_agreed','depositDueOn',starts+20) where id=t.id;
 assert (select record->>'depositDeadlinePolicy'='move_in_plus_10' and (record->>'depositDueOn')::date=starts+10 from public.bp_tenancies where id=t.id);
 delete from public.bp_notices where deposit_tenancy_id=t.id;
 perform public.bp_generate_deposit_reminders(null,t.starts+9);
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=t.id),'No reminder before tenth elapsed day';
 perform public.bp_generate_deposit_reminders(null,t.starts+10);
 assert (select count(*)=1 from public.bp_notices where deposit_tenancy_id=t.id and user_id='c3000000-0000-0000-0000-000000000001' and deposit_reminder_kind='payment'),'Warn at day10, not day20';
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=t.id and message like '%at least 10 days ago%'),'No misleading additional waiting-period text';
 perform public.bp_generate_deposit_reminders(null,t.starts+11);
 assert (select count(*)=1 from public.bp_notices where deposit_tenancy_id=t.id and user_id='c3000000-0000-0000-0000-000000000001' and deposit_reminder_kind='payment'),'Warning not duplicated';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('rent_term',jsonb_build_object('tenancyId',:'tid','period',to_char(date_trunc('month',current_date)+interval '1 month','YYYY-MM'),'amountCents',170000,'dueDay',22,'evidence','Agreed new rent; fixed first-day policy'));
do $$begin
 assert (select due_day=1 and amount=170000 from public.bp_rent_terms where tenancy_id=current_setting('test.fixed_tid')::uuid and period=(date_trunc('month',current_date)+interval '1 month')::date);
 begin perform public.bp_action('deposit_deadline',jsonb_build_object('tenancyId',current_setting('test.fixed_tid'),'date',current_date+20,'note','Try an extra twenty days'));raise exception 'FAIL: fixed deadline bypass';exception when raise_exception then assert sqlerrm like 'New tenants have 10 calendar days from move-in%';end;
 assert (public.bp_snapshot()->>'fixedRentalPolicyVersion')::integer=1;
 assert (public.bp_snapshot()->>'rentDueDay')::integer=1;
 assert (public.bp_snapshot()->>'depositPaymentDays')::integer=10;
end $$;
-- Pending deposit money is still not a receipt; no pay-again reminder for covered funds.
select set_config('request.jwt.claim.sub','c3000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','c4000000-0000-0000-0000-000000000001','amountCents',200000,'paidOn',current_date,'method','Cash','reference','FIXED-DEPOSIT-PENDING'));
select public.bp_check_deposit_reminders();
reset role;
do $$begin
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.fixed_tid')::uuid and deposit_reminder_kind='payment' and not read);
 assert exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.fixed_tid')::uuid and deposit_reminder_kind='review' and not read);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('deposit_review','{"id":"c4000000-0000-0000-0000-000000000001","confirm":true}');
select public.bp_check_deposit_reminders();
reset role;
do $$begin
 assert not exists(select 1 from public.bp_notices where deposit_tenancy_id=current_setting('test.fixed_tid')::uuid and not read);
 assert (select count(*)=1 from public.bp_case_records where tenancy_id=current_setting('test.fixed_tid')::uuid and kind='deposit' and body->>'event'='received');
end $$;
rollback;
\echo 'Fixed policy passed: day1 monthly rent, starts+10 once-off deposit with no extra delay, historical terms/receipts preserved, prior custom deadline retained, pending/receipt reminders and deprecated-op guard.'
