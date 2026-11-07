\set ON_ERROR_STOP on
begin;
do $$begin
 assert public.bp_rent_due('70000000-0000-0000-0000-000000000003','2026-01-01')=150000,'Upgrade never rewrites existing charges';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
create temporary table expected_first_month(tid uuid,starts date,expected integer);
do $$declare d record;r jsonb;n integer:=0;begin
 for d in select * from (values(date '2026-01-15',82258),(date '2026-02-15',75000),(date '2024-02-15',77586),(date '2026-04-15',80000),(date '2026-01-31',4839),(date '2026-01-01',150000)) as v(starts,amount) loop
 n:=n+1;
 r:=public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Calendar tenant '||n,'room',n,'start',d.starts));
 insert into expected_first_month values((r->>'result')::uuid,d.starts,d.amount);
 end loop;
 assert (public.bp_snapshot()->>'prorationVersion')::integer=1;
 assert exists(select 1 from jsonb_array_elements(public.bp_snapshot()->'tenancies') x where x->'record'->>'firstMonthProration'='actual_days');
end $$;
reset role;
do $$declare r record;begin
 for r in select * from expected_first_month loop
 assert public.bp_rent_due(r.tid,date_trunc('month',r.starts)::date)=r.expected,'Calendar-based final cent rounding';
 assert public.bp_rent_due(r.tid,(date_trunc('month',r.starts)+interval '1 month')::date)=150000,'Subsequent month is full monthly rent';
 end loop;
end $$;
set local role authenticated;
select tid as tid from expected_first_month where starts='2026-01-15' \gset
select set_config('test.proration_tid',:'tid',true);
do $$begin
 begin perform public.bp_action('payment',jsonb_build_object('tenancyId',current_setting('test.proration_tid'),'amountCents',82300,'method','Cash','payer','Tenant','reference','PRORATE-TOO-MUCH','paidOn','2026-01-15','received',true,'allocations',jsonb_build_array(jsonb_build_object('period','2026-01','amountCents',82300))));raise exception 'FAIL: overallocated first month';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',82258,'method','Cash','payer','Tenant','reference','PRORATE-EXACT','paidOn','2026-01-15','received',true,'allocations',jsonb_build_array(jsonb_build_object('period','2026-01','amountCents',82258))));
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Existing property","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"prorateFirstMonth":false}');
select public.bp_action('tenancy','{"propertyId":"70000000-0000-0000-0000-000000000002","name":"Full month agreed","room":7,"start":"2026-01-15"}');
select id as full_tid from public.bp_tenancies where room=7 \gset
reset role;
do $$begin
 assert public.bp_rent_due(current_setting('test.proration_tid')::uuid,'2026-01-01')=82258,'Property preference changes do not rewrite a recorded tenancy';
 assert (select not first_month_prorated from public.bp_tenancies where room=7),'Full-month option snapshots into new agreement';
 assert (select sum(amount)=82258 from public.bp_allocations where payment_id=(select id from public.bp_payments where reference='PRORATE-EXACT'));
 begin update public.bp_tenancies set first_month_prorated=false where id=current_setting('test.proration_tid')::uuid;raise exception 'FAIL: rewritten billing policy';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
-- Signup into an empty room snapshots the same policy as landlord onboarding.
update public.bp_properties set prorate_first=true where id='70000000-0000-0000-0000-000000000002';
insert into auth.users values('70000000-0000-0000-0000-000000000010','prorate-signup@test.invalid','{"name":"Signup Tenant","role":"tenant","phone":"0722222222","code":"BP-PRORATE","room":"8"}');
do $$begin assert (select first_month_prorated from public.bp_tenancies where tenant_id='70000000-0000-0000-0000-000000000010');end $$;
rollback;
\echo 'Proration checks passed: 28/29/30/31 days, inclusive dates, final cents, full subsequent months, preserved history, property choice and server allocation checks.'
