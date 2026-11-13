\set ON_ERROR_STOP on
begin;
-- Isolated actors: a linked owner/tenant plus an unrelated owner.
insert into auth.users values('d1100000-0000-0000-0000-000000000001','notice-owner@test.invalid','{"name":"Notice Owner","role":"landlord","phone":"0711234567"}');
insert into auth.users values('d1100000-0000-0000-0000-000000000002','notice-stranger@test.invalid','{"name":"Other Owner","role":"landlord","phone":"0711234568"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1100000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"name":"Notice Rooms","address":"1 Example Road","suburb":"Test area","city":"East London","postalCode":"5201","rooms":2,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}') as property_response \gset
select set_config('test.notice_property',(:'property_response'::jsonb->>'result'),true);
select public.bp_action('tenancy',jsonb_build_object('propertyId',current_setting('test.notice_property'),'name','Notice Tenant','room',1,'start',(now() at time zone 'Africa/Johannesburg')::date));
select id as tid,invitation as invite from public.bp_tenancies where property_id=current_setting('test.notice_property')::uuid and room=1 \gset
select set_config('test.notice_tid',:'tid',true);
reset role;
insert into auth.users values('d1100000-0000-0000-0000-000000000003','notice-tenant@test.invalid',jsonb_build_object('name','Notice Tenant','role','tenant','phone','0711234569','code',:'invite'));
-- Old generic history has no safely recoverable entity ID. Keep it unlinked.
insert into public.bp_notices(id,user_id,title,message) values('d1300000-0000-0000-0000-000000000099','d1100000-0000-0000-0000-000000000001','Old generic update','An earlier notification with no entity reference.');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1100000-0000-0000-0000-000000000003',true);
select public.bp_action('case',jsonb_build_object('tenancyId',:'tid','eventId','d1300000-0000-0000-0000-000000000001','kind','repair','body',jsonb_build_object('category','Other','urgency','Routine','incidentDate',(now() at time zone 'Africa/Johannesburg')::date,'cause','Unknown','accessAvailability','','location','Inside room','description','Window will not close.')));
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',1000,'payer','Notice Tenant','paidOn',(now() at time zone 'Africa/Johannesburg')::date,'method','Cash','reference','NOTICE-RENT-1','allocations',jsonb_build_array(jsonb_build_object('period',to_char((now() at time zone 'Africa/Johannesburg')::date,'YYYY-MM'),'amountCents',1000)))) as rent_response \gset
select set_config('test.notice_payment',(:'rent_response'::jsonb->>'result'),true);
select public.bp_action('deposit_report',jsonb_build_object('tenancyId',:'tid','eventId','d1300000-0000-0000-0000-000000000002','amountCents',10000,'paidOn',(now() at time zone 'Africa/Johannesburg')::date,'method','Cash','reference','NOTICE-DEPOSIT-1'));
select set_config('request.jwt.claim.sub','d1100000-0000-0000-0000-000000000001',true);
do $$declare s jsonb;begin
 s:=public.bp_snapshot();assert (s->>'actionableNoticesVersion')::integer=1;
 assert exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'targetKind'='issue' and n->>'targetId'='d1300000-0000-0000-0000-000000000001' and n->>'tenancyId'=current_setting('test.notice_tid') and n->>'message' like 'Notice Tenant · Room 1%Window will not close.%');
 assert exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'targetKind'='rent_payment' and n->>'targetId'=current_setting('test.notice_payment') and n->>'title'='Rent payment to check' and n->>'message' like 'Notice Tenant · Room 1 · Rent R 10.00%');
 assert exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'targetKind'='deposit_report' and n->>'targetId'='d1300000-0000-0000-0000-000000000002' and n->>'message' like 'Notice Tenant · Room 1 · Security deposit R 100.00%');
 assert exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'id'='d1300000-0000-0000-0000-000000000099' and n->>'targetKind' is null and n->>'targetId' is null),'Never guess a route for old ambiguous notices';
end $$;
select public.bp_action('review',jsonb_build_object('id',current_setting('test.notice_payment'),'confirm',true,'allocations',jsonb_build_array(jsonb_build_object('period',to_char((now() at time zone 'Africa/Johannesburg')::date,'YYYY-MM'),'amountCents',1000))));
select public.bp_action('deposit_review','{"id":"d1300000-0000-0000-0000-000000000002","confirm":true}');
select public.bp_action('case',jsonb_build_object('tenancyId',:'tid','eventId','d1300000-0000-0000-0000-000000000003','kind','case_update','body',jsonb_build_object('parentId','d1300000-0000-0000-0000-000000000001','status','acknowledged','message','I have received your issue.')));
-- Idempotent acknowledgement retry: no duplicate update or notice.
select public.bp_action('case',jsonb_build_object('tenancyId',:'tid','eventId','d1300000-0000-0000-0000-000000000003','kind','case_update','body',jsonb_build_object('parentId','d1300000-0000-0000-0000-000000000001','status','acknowledged','message','I have received your issue.')));
do $$begin
 assert (select body->>'status'='acknowledged' from public.bp_case_records where id='d1300000-0000-0000-0000-000000000003');
 assert not has_function_privilege('authenticated','public.bp_action_before_notice_routes(text,jsonb)','EXECUTE');
 assert not has_function_privilege('anon','public.bp_snapshot()','EXECUTE');
end $$;
select set_config('request.jwt.claim.sub','d1100000-0000-0000-0000-000000000003',true);
do $$declare s jsonb;begin
 s:=public.bp_snapshot();
 assert exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'title'='Rent payment confirmed' and n->>'targetKind'='rent_payment' and n->>'targetId'=current_setting('test.notice_payment'));
 assert exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'title'='Security deposit payment confirmed' and n->>'targetKind'='deposit_report' and n->>'targetId'='d1300000-0000-0000-0000-000000000002');
 assert nullif(current_setting('backyardpay.notice_request',true),'') is null,'Interactive route context must not leak to later actions';
 assert exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'title'='Issue acknowledged' and n->>'targetKind'='issue' and n->>'targetId'='d1300000-0000-0000-0000-000000000001');
 assert (select count(*)=1 from public.bp_notices where title='Issue acknowledged' and target_id='d1300000-0000-0000-0000-000000000001');
 assert not exists(select 1 from jsonb_array_elements(s->'notices') n where n->>'userId'<>'d1100000-0000-0000-0000-000000000003'),'Snapshot never exposes another recipient’s routes';
 begin perform public.bp_action('case',jsonb_build_object('tenancyId',current_setting('test.notice_tid'),'eventId',gen_random_uuid(),'kind','case_update','body',jsonb_build_object('parentId','d1300000-0000-0000-0000-000000000001','status','acknowledged','message','Tenant cannot acknowledge as landlord.')));raise exception 'FAIL: tenant changed status';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','d1100000-0000-0000-0000-000000000002',true);
do $$declare s jsonb;begin
 s:=public.bp_snapshot();assert jsonb_array_length(s->'notices')=0;assert jsonb_array_length(s->'caseRecords')=0;
 assert jsonb_array_length(s->'payments')=0;assert jsonb_array_length(s->'depositPaymentReports')=0;
 begin perform public.bp_action('case',jsonb_build_object('tenancyId',current_setting('test.notice_tid'),'eventId',gen_random_uuid(),'kind','case_update','body',jsonb_build_object('parentId','d1300000-0000-0000-0000-000000000001','status','acknowledged','message','Other owner cannot acknowledge.')));raise exception 'FAIL: unrelated owner changed status';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
rollback;
\echo 'Actionable notices passed: exact issue/rent/deposit destinations, identified tenants, acknowledgment status/replay, recipient RLS and unlinked legacy fallback.'
