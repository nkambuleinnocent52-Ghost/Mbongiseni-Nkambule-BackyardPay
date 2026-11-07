\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Simple rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('room_rents','{"propertyId":"70000000-0000-0000-0000-000000000002","rates":{"6":200000,"7":200000,"8":200000,"9":200000}}');
select public.bp_action('tenancy','{"propertyId":"70000000-0000-0000-0000-000000000002","name":"Large room tenant","room":6,"start":"2026-01-15"}');
select id as tid,invitation as invite from public.bp_tenancies where room=6 \gset
select set_config('test.simple_tid',:'tid',true);
select public.bp_action('tenancy','{"propertyId":"70000000-0000-0000-0000-000000000002","name":"Default room tenant","room":5,"start":"2026-01-15"}');
select id as tid2,invitation as invite2 from public.bp_tenancies where room=5 \gset
reset role;
do $$begin
 assert (select rent=200000 from public.bp_tenancies where id=current_setting('test.simple_tid')::uuid);
 assert public.bp_rent_due(current_setting('test.simple_tid')::uuid,'2026-01-01')=109677,'Prorated override uses calendar days';
 assert public.bp_rent_due(current_setting('test.simple_tid')::uuid,'2026-02-01')=200000;
 assert (select rent=150000 from public.bp_tenancies where room=5),'Unchanged rooms use default';
end $$;
insert into auth.users values('91000000-0000-0000-0000-000000000001','simple@test.invalid',jsonb_build_object('name','Simple tenant','role','tenant','phone','0711111111','code',:'invite'));
insert into auth.users values('91000000-0000-0000-0000-000000000002','default@test.invalid',jsonb_build_object('name','Default tenant','role','tenant','phone','0711111112','code',:'invite2'));
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('room_rents','{"propertyId":"70000000-0000-0000-0000-000000000002","rates":{}}');
do $$begin
 assert (select rent=200000 from public.bp_tenancies where id=current_setting('test.simple_tid')::uuid),'Removing override does not rewrite existing rental';
 begin perform public.bp_action('room_rents','{"propertyId":"70000000-0000-0000-0000-000000000002","rates":{"31":200000}}');raise exception 'FAIL: nonexistent room';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('room_rents','{"propertyId":"70000000-0000-0000-0000-000000000002","rates":{"6":0}}');raise exception 'FAIL: zero rent';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('deposit_update',jsonb_build_object('tenancyId',:'tid','eventId','92000000-0000-0000-0000-000000000001','body',jsonb_build_object('event','received','amountCents',200000,'date',current_date,'reference','CASH-RECEIPT')));
-- Replaying the same event does not double count the deposit.
select public.bp_action('deposit_update',jsonb_build_object('tenancyId',:'tid','eventId','92000000-0000-0000-0000-000000000001','body',jsonb_build_object('event','received','amountCents',200000,'date',current_date,'reference','CASH-RECEIPT')));
do $$begin
 begin perform public.bp_action('deposit_update',jsonb_build_object('tenancyId',current_setting('test.simple_tid'),'eventId',gen_random_uuid(),'body',jsonb_build_object('event','deduction','amountCents',200000,'date',current_date,'reference','DAMAGE')));raise exception 'FAIL: unsupported deduction';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('deposit_update',jsonb_build_object('tenancyId',:'tid','eventId',gen_random_uuid(),'body',jsonb_build_object('event','deduction','amountCents',50000,'date',current_date,'reference','WINDOW-INVOICE','note','Supported broken window replacement','evidence','Move-in and exit condition records plus R500 invoice','groundsConfirmed',true)));
select public.bp_action('deposit_update',jsonb_build_object('tenancyId',:'tid','eventId',gen_random_uuid(),'body',jsonb_build_object('event','refund','amountCents',150000,'date',current_date,'reference','EFT-REFUND','note','Remaining deposit returned')));
select public.bp_action('property_message',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','eventId','93000000-0000-0000-0000-000000000001','tenancyId',:'tid','message','Your tap repair is booked'));
select public.bp_action('property_message','{"propertyId":"70000000-0000-0000-0000-000000000002","eventId":"93000000-0000-0000-0000-000000000002","message":"Shared water pipe repair at noon"}');
select public.bp_action('property_message','{"propertyId":"70000000-0000-0000-0000-000000000002","eventId":"93000000-0000-0000-0000-000000000002","message":"Shared water pipe repair at noon"}');
reset role;
do $$begin
 assert (select count(*)=3 from public.bp_case_records where tenancy_id=current_setting('test.simple_tid')::uuid and kind='deposit');
 assert (select sum(case when body->>'event'='received' then (body->>'amountCents')::integer else -(body->>'amountCents')::integer end)=0 from public.bp_case_records where tenancy_id=current_setting('test.simple_tid')::uuid and kind='deposit');
 assert (select count(*)=1 from public.bp_notices where title='Security deposit updated' and message like '%broken window%');
 assert (select count(*)=1 from public.bp_notices where message='Your tap repair is booked');
 assert (select count(*)=2 from public.bp_notices where message='Shared water pipe repair at noon'),'Broadcast once per linked tenant, no duplicates';
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',true);
do $$begin
 assert (public.bp_snapshot()->>'simpleRentalsVersion')::integer=1;
 begin perform public.bp_action('room_rents','{"propertyId":"70000000-0000-0000-0000-000000000002","rates":{"6":1}}');raise exception 'FAIL: tenant changed rates';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('property_message','{"propertyId":"70000000-0000-0000-0000-000000000002","eventId":"93000000-0000-0000-0000-000000000003","message":"Unauthorized broadcast"}');raise exception 'FAIL: tenant broadcast';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('deposit_update',jsonb_build_object('tenancyId',current_setting('test.simple_tid'),'eventId',gen_random_uuid(),'body',jsonb_build_object('event','received','amountCents',1,'date',current_date,'reference','FAKE')));raise exception 'FAIL: tenant marked own deposit received';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
rollback;
\echo 'Simple rentals passed: room rates/proration, existing terms preserved, deposit receipt/deduction/refund, targeted and property notifications, replay safety and authorization.'
