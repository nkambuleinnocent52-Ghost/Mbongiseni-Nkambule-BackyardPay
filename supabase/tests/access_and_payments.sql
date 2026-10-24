\set ON_ERROR_STOP on
begin;
-- Auth trigger performs profile setup. No seed data is shipped to the real DB.
insert into auth.users values
('10000000-0000-0000-0000-000000000001','owner1@example.test','{"role":"landlord","name":"Owner One","phone":"0711111111"}'),
('10000000-0000-0000-0000-000000000002','owner2@example.test','{"role":"landlord","name":"Owner Two","phone":"0722222222"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"name":"First Rooms","address":"1 Test Lane","rooms":2,"rentCents":150000,"dueDay":1,"suburb":"","city":"East London","postalCode":"5201"}');
reset role;
select id as prop1, code as code1 from public.bp_properties where owner_id='10000000-0000-0000-0000-000000000001' \gset
insert into auth.users values('20000000-0000-0000-0000-000000000001','tenant1@example.test',jsonb_build_object('role','tenant','name','Tenant One','phone','0733333333','room','1','code',:'code1'));
insert into auth.users values('20000000-0000-0000-0000-000000000002','tenant2@example.test',jsonb_build_object('role','tenant','name','Tenant Two','phone','0744444444','room','2','code',:'code1'));
select id as tenancy1 from public.bp_tenancies where tenant_id='20000000-0000-0000-0000-000000000001' \gset
-- Store IDs as settings so PL/pgSQL assertions need no text interpolation.
select set_config('test.tenancy',:'tenancy1',true),set_config('test.property',:'prop1',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
do $$declare s jsonb; begin
 s:=public.bp_snapshot();
 assert jsonb_array_length(s->'tenancies')=1,'Tenant must see only own tenancy';
 assert jsonb_array_length(s->'accounts')=2,'Tenant must not see another tenant';
 assert not exists(select 1 from public.bp_profiles where email='tenant2@example.test'),'Profile RLS isolation';
 begin
   perform public.bp_action('property','{"name":"Attack","address":"Invalid Lane","rooms":1,"rentCents":10,"dueDay":1}');
   raise exception 'FAIL: tenant created property';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
   update public.bp_tenancies set rent=1;
   raise exception 'FAIL: direct write permitted';
 exception when insufficient_privilege then null; end;
 begin
   perform public.bp_action('payment',jsonb_build_object('tenancyId',current_setting('test.tenancy'),'period',to_char(current_date,'YYYY-MM'),'amountCents',150000,'method','EFT','paidOn',current_date,'reference','NO-BANK','bankReference',''));
   raise exception 'FAIL: missing bank reference accepted';
 exception when check_violation then null; end;
end $$;
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tenancy1','period',to_char(current_date,'YYYY-MM'),'amountCents',60000,'method','EFT','paidOn',current_date,'reference','TEST-PARTIAL','bankReference','BANK-123'));
select id as payment1 from public.bp_payments where reference='TEST-PARTIAL' \gset
select set_config('test.payment',:'payment1',true);
do $$begin
 begin
   perform public.bp_action('review',jsonb_build_object('id',current_setting('test.payment'),'confirm',true));
   raise exception 'FAIL: tenant confirmed own payment';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
   perform public.bp_action('payment',jsonb_build_object('tenancyId',current_setting('test.tenancy'),'period',to_char(current_date,'YYYY-MM'),'amountCents',100000,'method','Cash','paidOn',current_date,'reference','TOO-MUCH'));
   raise exception 'FAIL: pending overpayment accepted';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
-- Unrelated landlord cannot see or mutate other household records.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
do $$declare s jsonb; begin
 s:=public.bp_snapshot(); assert jsonb_array_length(s->'properties')=0;
 assert jsonb_array_length(s->'payments')=0;
 begin
   perform public.bp_action('review',jsonb_build_object('id',current_setting('test.payment'),'confirm',true));
   raise exception 'FAIL: unrelated owner reviewed payment';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
   perform public.bp_action('location',jsonb_build_object('id',current_setting('test.property'),'latitude',1,'longitude',1));
   raise exception 'FAIL: unrelated owner changed location';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.bp_action('review',jsonb_build_object('id',:'payment1','confirm',true));
do $$begin
 assert (select state='confirmed' and bank_reference='BANK-123' from public.bp_payments where id=current_setting('test.payment')::uuid);
 assert jsonb_array_length(public.bp_snapshot()->'tenancies')=2;
 begin
   perform public.bp_action('review',jsonb_build_object('id',current_setting('test.payment'),'confirm',true));
   raise exception 'FAIL: reviewed twice';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
end $$;
select public.bp_action('agreement',jsonb_build_object('tenancyId',:'tenancy1','start',current_date,'agreementType','Month-to-month','depositCents',150000,'depositReceivedCents',50000,'utilities','Water included','houseRules','One month notice','emergencyName','','emergencyPhone',''));
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select public.bp_action('acknowledge',jsonb_build_object('tenancyId',:'tenancy1'));
do $$begin
 assert (select acknowledged_at is not null from public.bp_tenancies where id=current_setting('test.tenancy')::uuid);
 assert exists(select 1 from public.bp_notices where title='Payment confirmed');
end $$;
reset role;
do $$begin
 begin
   insert into auth.users values('20000000-0000-0000-0000-000000000003','race@example.test',jsonb_build_object('role','tenant','name','Third Tenant','phone','0755555555','room','1','code',(select code from public.bp_properties where id=current_setting('test.property')::uuid)));
   raise exception 'FAIL: occupied room claimed twice';
 exception when raise_exception then if sqlerrm like 'FAIL:%' then raise; end if; end;
 assert not exists(select 1 from auth.users where email='race@example.test'),'Failed signup must roll back';
end $$;
set local role anon;
do $$begin
 begin perform public.bp_snapshot(); raise exception 'FAIL: anonymous snapshot allowed'; exception when insufficient_privilege then null; end;
 begin perform public.bp_action('profile','{}'); raise exception 'FAIL: anonymous mutation allowed'; exception when insufficient_privilege then null; end;
end $$;
rollback;
\echo 'Database checks passed: RLS isolation, signup, room occupancy, pending/partial payments, bank references, approval authorization, rental terms and acknowledgement.'
