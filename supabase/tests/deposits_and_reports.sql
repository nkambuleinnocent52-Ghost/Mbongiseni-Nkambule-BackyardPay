\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
do $$begin
 assert (select not terms ? 'depositCents' from public.bp_tenancies where id='70000000-0000-0000-0000-000000000003'),'No invented deposit on existing agreement';
 begin perform public.bp_action('tenancy','{"propertyId":"70000000-0000-0000-0000-000000000002","name":"Missing deposit","room":9,"start":"2026-01-15"}');raise exception 'FAIL: no deposit choice';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Existing property","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('tenancy','{"propertyId":"70000000-0000-0000-0000-000000000002","name":"Deposit Tenant","room":9,"start":"2026-01-15"}');
select id as tid,invitation as invite from public.bp_tenancies where room=9 \gset
select set_config('test.deposit_tid',:'tid',true);
do $$begin
 assert (select (terms->>'depositCents')::integer=200000 and (terms->>'depositReceivedCents')::integer=0 from public.bp_tenancies where id=current_setting('test.deposit_tid')::uuid);
 assert (public.bp_snapshot()->>'depositReportsVersion')::integer=1;
end $$;
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Existing property","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":300000}');
reset role;
do $$begin
 assert public.bp_rent_due(current_setting('test.deposit_tid')::uuid,'2026-01-01')=82258,'Rent remains prorated, not inflated by deposit';
 assert (select (terms->>'depositCents')::integer=200000 from public.bp_tenancies where id=current_setting('test.deposit_tid')::uuid),'Property changes do not rewrite agreed deposit';
end $$;
insert into auth.users values('80000000-0000-0000-0000-000000000001','reporter@test.invalid',jsonb_build_object('name','Reporter','role','tenant','phone','0722222222','code',:'invite','room','9'));
insert into auth.users values('80000000-0000-0000-0000-000000000002','unrelated@test.invalid','{"name":"Other Owner","role":"landlord","phone":"0733333333"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','80000000-0000-0000-0000-000000000001',true);
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','repair','body',jsonb_build_object('category','Water / plumbing','urgency','Urgent','incidentDate',current_date,'location','Outside shared tap','cause','Unknown','description','Water leaks continuously at shared tap','accessAvailability','Contact before visiting')));
select id as report from public.bp_case_records where kind='repair' and tenancy_id=:'tid' \gset
select set_config('test.report',:'report',true);
-- A tenant can report their own accidental damage without an automatic financial penalty.
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','repair','body',jsonb_build_object('category','Damage inside my room','urgency','Routine','incidentDate',current_date,'location','Room 9 window','cause','I or my household caused it','description','I accidentally broke the window; arrange inspection')));
do $$begin
 assert (select count(*)=0 from public.bp_case_records where tenancy_id=current_setting('test.deposit_tid')::uuid and kind='deposit'),'Reports must not deduct money';
 assert (select count(*)=0 from public.bp_payments where tenancy_id=current_setting('test.deposit_tid')::uuid),'Reports must not create rent charges/payments';
 begin perform public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',current_setting('test.deposit_tid'),'kind','repair','body',jsonb_build_object('category','Damage inside my room','urgency','Routine','incidentDate',current_date,'location','Room 9','cause','Unknown','description','Test malicious financial fields','deductionCents',200000)));raise exception 'FAIL: report charged money';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
insert into storage.objects(bucket_id,name,owner_id) values('bp-documents',:'tid'||'/80000000-0000-0000-0000-000000000003.jpg',auth.uid()::text);
select public.bp_register_case_document(:'tid',:'tid'||'/80000000-0000-0000-0000-000000000003.jpg','Shared tap photo','Other',:'report');
select set_config('request.jwt.claim.sub','80000000-0000-0000-0000-000000000002',true);
do $$begin assert (select count(*)=0 from public.bp_case_records);assert (select count(*)=0 from public.bp_documents);end $$;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','case_update','body',jsonb_build_object('parentId',:'report','status','in_progress','message','Plumber contacted; agreeing access')));
-- Record actual deposit component only, independent of rent.
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','deposit','body',jsonb_build_object('event','received','amountCents',50000,'date',current_date,'reference','PARTIAL-DEPOSIT','payer','Tenant','method','Cash')));
do $$begin
 assert (select sum((body->>'amountCents')::integer)=50000 from public.bp_case_records where tenancy_id=current_setting('test.deposit_tid')::uuid and kind='deposit');
 assert (select count(*)=1 from public.bp_documents where case_id=current_setting('test.report')::uuid);
end $$;
rollback;
\echo 'Deposit/report checks passed: explicit property deposit, tenancy snapshot, no fake receipts, rent separation, tenant self-damage and shared repairs, no automatic charges, report attachments and RLS.'
