\set ON_ERROR_STOP on
begin;
set local timezone='Africa/Johannesburg';
-- Existing test-suite owner and property from legacy_upgrade_fixture.
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Agreement rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('property_agreement',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','details',jsonb_build_object(
 'landlordAddress','1 Owner Street, East London','authority','Property owner','sharedFacilities','Shared tap and gate','paymentInstructions','Cash by arrangement or EFT reference room number','utilities','Water included; tenant buys electricity','houseRules','Keep shared areas clear','noticeTerms','Actual agreement: one calendar month notice','escalationTerms','As agreed in writing','otherCharges','None')));
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Shared Terms Test','room',26,'start',current_date-1));
select id as terms_tid from public.bp_tenancies where room=26 \gset
select set_config('test.terms_tid',:'terms_tid',true);
do $$declare t public.bp_tenancies;s jsonb;begin
 select * into t from public.bp_tenancies where id=current_setting('test.terms_tid')::uuid;
 assert t.record->>'landlordAddress'='1 Owner Street, East London';
 assert t.record->>'paymentInstructions'='Cash by arrangement or EFT reference room number';
 assert t.terms->>'utilities'='Water included; tenant buys electricity';
 assert t.terms->>'houseRules'='Keep shared areas clear';
 s:=public.bp_snapshot();assert (s->>'agreementDefaultsVersion')::integer=1;
 assert exists(select 1 from jsonb_array_elements(s->'propertyAgreements') e where e->>'propertyId'='70000000-0000-0000-0000-000000000002');
 begin perform public.bp_action('agreement',jsonb_build_object('tenancyId',t.id,'start',t.starts-1));raise exception 'FAIL: edited actual move-in';exception when raise_exception then assert sqlerrm='Move-in date is fixed from tenant onboarding.';end;
 begin perform public.bp_action('agreement',jsonb_build_object('tenancyId',t.id,'start',t.starts,'depositCents',coalesce((t.terms->>'depositCents')::integer,0)+1));raise exception 'FAIL: edited deposit';exception when raise_exception then assert sqlerrm like 'The security deposit is fixed from tenant onboarding%';end;
end $$;
-- Revising defaults does not rewrite an existing rental snapshot.
select public.bp_action('property_agreement',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','details',jsonb_build_object(
 'landlordAddress','2 New Owner Street, East London','authority','Property owner','sharedFacilities','Shared tap and gate','paymentInstructions','New EFT instructions','utilities','Water included','houseRules','Keep shared areas clear','noticeTerms','Actual agreement: one calendar month notice','escalationTerms','As agreed in writing','otherCharges','None')));
do $$begin
 assert (select record->>'landlordAddress'='1 Owner Street, East London' from public.bp_tenancies where id=current_setting('test.terms_tid')::uuid);
 assert (select jsonb_array_length(history)=1 from public.bp_property_agreements where property_id='70000000-0000-0000-0000-000000000002');
end $$;
-- Another landlord cannot read or change the owner's defaults.
select set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
do $$begin
 assert not exists(select 1 from public.bp_property_agreements where property_id='70000000-0000-0000-0000-000000000002');
 begin perform public.bp_action('property_agreement','{"propertyId":"70000000-0000-0000-0000-000000000002","details":{}}');raise exception 'FAIL: unauthorized defaults';exception when raise_exception then assert sqlerrm='Property unavailable.';end;
end $$;
rollback;
\echo 'Agreement defaults passed: owner RLS, copied new-tenancy terms, fixed move-in/deposit and historic snapshots preserved.'
