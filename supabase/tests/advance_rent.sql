\set ON_ERROR_STOP on
begin;
set local timezone='Africa/Johannesburg';
select to_char(date_trunc('month',current_date),'YYYY-MM') as month_now,
 to_char(date_trunc('month',current_date)+interval '1 month','YYYY-MM') as month_next,
 to_char(date_trunc('month',current_date)+interval '12 months','YYYY-MM') as month_limit,
 to_char(date_trunc('month',current_date)+interval '13 months','YYYY-MM') as month_outside,
 date_trunc('month',current_date)::date as starts \gset
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Advance rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":0,"prorateFirstMonth":true}');
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Advance tenant','room',27,'start',:'starts'));
select id as tid,invitation as invite from public.bp_tenancies where room=27 \gset
select set_config('test.advance_tid',:'tid',true),set_config('test.advance_next',:'month_next',true),set_config('test.advance_limit',:'month_limit',true),set_config('test.advance_outside',:'month_outside',true);
-- Known future rent is used, rather than blindly copying the current month's charge.
select public.bp_action('rent_term',jsonb_build_object('tenancyId',:'tid','period',:'month_next','amountCents',180000,'dueDay',1,'evidence','Agreed rate from next month'));
reset role;
insert into auth.users values('94000000-0000-0000-0000-000000000001','advance@test.invalid',jsonb_build_object('name','Advance tenant','role','tenant','phone','0711111127','code',:'invite'));
set local role authenticated;
select set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',180000,'method','EFT','bankReference','BANK-ADVANCE-1','reference','ADVANCE-RENT-1','payer','Advance tenant','paidOn',current_date,'allocations',jsonb_build_array(jsonb_build_object('period',:'month_next','amountCents',180000))));
select id as payid from public.bp_payments where reference='ADVANCE-RENT-1' \gset
select set_config('test.advance_pay',:'payid',true);
do $$begin
 assert (select state='pending' from public.bp_payments where id=current_setting('test.advance_pay')::uuid),'Tenant report stays pending';
 assert (select coalesce(sum(a.amount),0)=0 from public.bp_allocations a join public.bp_payments p on p.id=a.payment_id where p.tenancy_id=current_setting('test.advance_tid')::uuid and p.state='confirmed'),'Pending advance payment is not confirmed rent';
 begin perform public.bp_action('review',jsonb_build_object('id',current_setting('test.advance_pay'),'confirm',true,'allocations','[]'::jsonb));raise exception 'FAIL: tenant confirmed own payment';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('review',jsonb_build_object('id',:'payid','confirm',true,'allocations',jsonb_build_array(jsonb_build_object('period',:'month_next','amountCents',180000))));
-- Twelve-month boundary works; months beyond it do not. Already-received credit may also be assigned forward.
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',180000,'method','Cash','reference','ADVANCE-CREDIT','payer','Advance tenant','paidOn',current_date,'received',true,'allocations','[]'::jsonb));
select id as creditid from public.bp_payments where reference='ADVANCE-CREDIT' \gset
select public.bp_action('allocate_credit',jsonb_build_object('id',:'creditid','allocations',jsonb_build_array(jsonb_build_object('period',:'month_limit','amountCents',180000))));
do $$begin
 begin perform public.bp_action('payment',jsonb_build_object('tenancyId',current_setting('test.advance_tid'),'amountCents',100,'method','Cash','reference','BEFORE-START','payer','Advance tenant','paidOn',current_date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',to_char(date_trunc('month',current_date)-interval '1 month','YYYY-MM'),'amountCents',100))));raise exception 'FAIL: rent before tenancy';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('payment',jsonb_build_object('tenancyId',current_setting('test.advance_tid'),'amountCents',100,'method','Cash','reference','TOO-FAR','payer','Advance tenant','paidOn',current_date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.advance_outside'),'amountCents',100))));raise exception 'FAIL: month past horizon';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('payment',jsonb_build_object('tenancyId',current_setting('test.advance_tid'),'amountCents',100,'method','Cash','reference','OVER-PREPAID','payer','Advance tenant','paidOn',current_date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.advance_next'),'amountCents',100))));raise exception 'FAIL: over-allocated prepaid month';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('rent_term',jsonb_build_object('tenancyId',current_setting('test.advance_tid'),'period',current_setting('test.advance_limit'),'amountCents',140000,'dueDay',1,'evidence','Reduction after prepayment'));raise exception 'FAIL: prepaid month reduced below receipt';exception when raise_exception then assert sqlerrm like 'This rent change is below money already confirmed%';end;
 begin perform public.bp_action('close_tenancy',jsonb_build_object('tenancyId',current_setting('test.advance_tid'),'date',current_date,'note','Actual return'));raise exception 'FAIL: handover with future confirmed allocations';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
reset role;
do $$begin
 assert public.bp_rent_due(current_setting('test.advance_tid')::uuid,date_trunc('month',current_date)::date)=150000,'Next month payment does not erase current month charge';
 assert (select count(*)=0 from public.bp_allocations a join public.bp_payments p on p.id=a.payment_id where p.tenancy_id=current_setting('test.advance_tid')::uuid and a.period=date_trunc('month',current_date)::date),'Advance allocation stays in its stated month';
 assert public.bp_rent_due(current_setting('test.advance_tid')::uuid,(current_setting('test.advance_next')||'-01')::date)=180000,'Dated future rate retained';
 assert (select receipt_details->'issuedAllocations'->0->>'period'=current_setting('test.advance_next') from public.bp_payments where id=current_setting('test.advance_pay')::uuid),'Receipt identifies the future rental month';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
-- Actual reversal is retained; after future payments are reconciled, handover can be recorded.
select public.bp_action('reverse_payment',jsonb_build_object('id',:'payid','reason','Advance payment actually returned before handover'));
select public.bp_action('reverse_payment',jsonb_build_object('id',:'creditid','reason','Unused advance credit returned before handover'));
select public.bp_action('close_tenancy',jsonb_build_object('tenancyId',:'tid','date',current_date,'note','Keys returned and future payments refunded'));
do $$begin
 begin perform public.bp_action('payment',jsonb_build_object('tenancyId',current_setting('test.advance_tid'),'amountCents',100,'method','Cash','reference','AFTER-HANDOVER','payer','Advance tenant','paidOn',current_date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',current_setting('test.advance_next'),'amountCents',100))));raise exception 'FAIL: rent after actual handover';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
rollback;
\echo 'Advance rent checks passed: tenant report/owner review, next-month and 12-month allocations, dated rates, current-month separation, overpayment/role/end guards and reconciled handover.'
