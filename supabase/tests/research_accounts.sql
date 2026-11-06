\set ON_ERROR_STOP on
begin;
insert into auth.users values
('10000000-0000-0000-0000-000000000001','owner1@research.test','{"role":"landlord","name":"Owner One","phone":"0711111111"}'),
('10000000-0000-0000-0000-000000000002','owner2@research.test','{"role":"landlord","name":"Owner Two","phone":"0722222222"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"name":"Research Rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":3,"rentCents":150000,"dueDay":1}');
select id as prop from public.bp_properties where name='Research Rooms' \gset
select public.bp_action('tenancy',jsonb_build_object('propertyId',:'prop','name','Recorded Tenant','phone','0733333333','email','tenant@research.test','room',1,'start',(date_trunc('month',current_date)-interval '2 months')::date));
select id as tid,invitation as invitation from public.bp_tenancies where property_id=:'prop' \gset
select set_config('test.tenancy',:'tid',true),set_config('test.property',:'prop',true);
select public.bp_action('agreement',jsonb_build_object('tenancyId',:'tid','start',(date_trunc('month',current_date)-interval '2 months')::date,'end',(date_trunc('month',current_date)-interval '1 day')::date,'agreementType','Fixed term','depositCents',150000,'utilities','Water included','houseRules','Keep shared facilities clean','details',jsonb_build_object('landlordAddress','1 Owner Street','tenantAddress','Room 1, 1 Test Street','authority','Owner (recorded)','dwellingDescription','Backyard brick room 1','sharedFacilities','Shared tap','paymentInstructions','Cash or bank transfer to agreed beneficiary','noticeTerms','Written notice under agreed terms and applicable law','escalationTerms','No automatic increase','otherCharges','None')));
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',90000,'method','Cash','reference','RESEARCH-SEP','payer','Tenant relative','paidOn',(date_trunc('month',current_date)-interval '2 months')::date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',to_char(current_date-interval '2 months','YYYY-MM'),'amountCents',90000))));
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',210000,'method','Cash deposit','bankReference','BANK-2100','reference','RESEARCH-OCT','payer','Actual payer','paidOn',(date_trunc('month',current_date)-interval '1 month')::date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',to_char(current_date-interval '2 months','YYYY-MM'),'amountCents',60000),jsonb_build_object('period',to_char(current_date-interval '1 month','YYYY-MM'),'amountCents',150000))));
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',180000,'method','EFT','bankReference','BANK-1800','reference','RESEARCH-CREDIT','payer','Payer','paidOn',current_date,'received',true,'allocations',jsonb_build_array(jsonb_build_object('period',to_char(current_date,'YYYY-MM'),'amountCents',150000))));
select id as pay from public.bp_payments where reference='RESEARCH-CREDIT' \gset
select set_config('test.payment',:'pay',true);
do $$declare s jsonb;begin
 s:=public.bp_snapshot();assert (s->>'researchVersion')::integer=2;assert jsonb_array_length(s->'payments')=3;
 assert (select count(*)=4 and sum(amount)=450000 from public.bp_allocations),'One payment may cover multiple months';
 assert (select receipt_details->>'tenant'='Recorded Tenant' and (receipt_details->>'issuedCreditCents')::integer=30000 from public.bp_payments where id=current_setting('test.payment')::uuid),'Receipt snapshot and unallocated credit retained';
 begin perform public.bp_action('allocate_credit',jsonb_build_object('id',current_setting('test.payment'),'allocations',jsonb_build_array(jsonb_build_object('period',to_char(current_date,'YYYY-MM'),'amountCents',10000))));raise exception 'FAIL: allocated beyond charge';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','adjustment','body',jsonb_build_object('period',to_char(current_date,'YYYY-MM'),'amountCents',20000,'reason','Additional agreed charge, written reference A1')));
select public.bp_action('allocate_credit',jsonb_build_object('id',:'pay','allocations',jsonb_build_array(jsonb_build_object('period',to_char(current_date,'YYYY-MM'),'amountCents',20000))));
do $$begin
 assert (select amount=170000 from public.bp_allocations where payment_id=current_setting('test.payment')::uuid and period=date_trunc('month',current_date)::date);
 assert (select (receipt_details->>'issuedCreditCents')::integer=30000 from public.bp_payments where id=current_setting('test.payment')::uuid),'Credit allocation must not rewrite original receipt';
end $$;
-- Deposit transactions are distinct from rent and cannot be doubled on retry.
select gen_random_uuid() as event \gset
select public.bp_action('case',jsonb_build_object('eventId',:'event','tenancyId',:'tid','kind','deposit','body',jsonb_build_object('event','received','amountCents',150000,'date',current_date,'reference','DEP-PAID','payer','Actual payer','method','Cash','note','Agreed deposit')));
select public.bp_action('case',jsonb_build_object('eventId',:'event','tenancyId',:'tid','kind','deposit','body',jsonb_build_object('event','received','amountCents',150000,'date',current_date,'reference','DEP-PAID','payer','Actual payer','method','Cash','note','Agreed deposit')));
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','deposit','body',jsonb_build_object('event','interest','amountCents',1000,'date',current_date,'reference','BANK-INTEREST')));
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','deposit','body',jsonb_build_object('event','refund','amountCents',40000,'date',current_date,'reference','REFUND-RECORD')));
do $$begin
 assert (select count(*)=3 from public.bp_case_records where kind='deposit'),'Retry did not duplicate deposit';
 assert (select sum(amount)=480000 from public.bp_payments),'Deposit excluded from rent money';
 begin perform public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',current_setting('test.tenancy'),'kind','deposit','body',jsonb_build_object('event','deduction','amountCents',10000,'date',current_date,'reference','COST-RECEIPT','note','Claimed damage')));raise exception 'FAIL: deduction without inspections';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin perform public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',current_setting('test.tenancy'),'kind','deposit','body',jsonb_build_object('event','refund','amountCents',999999,'date',current_date,'reference','INVALID')));raise exception 'FAIL: excessive refund';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','inspection','body',jsonb_build_object('stage','Entry','date',(date_trunc('month',current_date)-interval '2 months')::date,'participants','Landlord and tenant named on signed sheet','condition','Crack at window recorded')));
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','inspection','body',jsonb_build_object('stage','Exit','date',current_date,'participants','Landlord and tenant named on signed sheet','condition','Inspection recorded with supporting evidence')));
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','deposit','body',jsonb_build_object('event','deduction','amountCents',10000,'date',current_date,'reference','ACTUAL-COST-RECEIPT','note','Claimed deduction, legal conditions checked separately')));
select public.bp_action('rent_term',jsonb_build_object('tenancyId',:'tid','period',to_char(current_date+interval '1 month','YYYY-MM'),'amountCents',200000,'dueDay',3,'evidence','Future rate agreed, reference L2'));
-- Storage policy and metadata contract (actual file transfer needs hosted Storage).
insert into storage.objects(bucket_id,name,owner_id) values('bp-documents',current_setting('test.tenancy')||'/30000000-0000-0000-0000-000000000001.pdf',auth.uid()::text);
select public.bp_register_document(:'tid',:'tid'||'/30000000-0000-0000-0000-000000000001.pdf','Recorded signed lease copy','Lease');
do $$begin
 delete from storage.objects where bucket_id='bp-documents';
 assert (select count(*)=1 from storage.objects),'Registered evidence cannot be deleted';
 begin perform public.bp_register_document(current_setting('test.tenancy')::uuid,current_setting('test.tenancy')||'/30000000-0000-0000-0000-000000000002.pdf','Missing upload','Lease');raise exception 'FAIL: registered missing object';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
-- Unrelated landlords cannot read or alter this household.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
do $$begin
 assert (select count(*)=0 from public.bp_documents);assert (select count(*)=0 from storage.objects);
 assert jsonb_array_length(public.bp_snapshot()->'caseRecords')=0;assert jsonb_array_length(public.bp_snapshot()->'tenancies')=0;
 begin perform public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',current_setting('test.tenancy'),'kind','query','body',jsonb_build_object('description','Attack')));raise exception 'FAIL: unrelated record mutation';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
reset role;
-- Claiming an occupied room by public property code is rejected.
do $$begin
 begin insert into auth.users values('20000000-0000-0000-0000-000000000002','intruder@research.test',jsonb_build_object('role','tenant','name','Intruder','phone','0744444444','room','1','code',(select code from public.bp_properties where id=current_setting('test.property')::uuid)));raise exception 'FAIL: claimed occupied room';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
insert into auth.users values('20000000-0000-0000-0000-000000000001','tenant@research.test',jsonb_build_object('role','tenant','name','Connected Tenant','phone','0733333333','room','1','code',:'invitation'));
set local role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
do $$begin
 assert (select count(*)=1 from public.bp_documents);assert (select count(*)=1 from storage.objects);
 assert jsonb_array_length(public.bp_snapshot()->'payments')=3,'Tenant inherits existing rental history through private invitation';
 begin perform public.bp_action('rent_term',jsonb_build_object('tenancyId',current_setting('test.tenancy'),'period',to_char(current_date+interval '1 month','YYYY-MM'),'amountCents',1,'dueDay',1,'evidence','Attack'));raise exception 'FAIL: tenant rent change';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 begin update public.bp_allocations set amount=1;raise exception 'FAIL: direct financial writes';exception when insufficient_privilege then null;end;
end $$;
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','query','body',jsonb_build_object('description','Please explain the recorded charge adjustment')));
select id as issue from public.bp_case_records where kind='query' \gset
select set_config('test.issue',:'issue',true);
do $$begin
 begin perform public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',current_setting('test.tenancy'),'kind','case_update','body',jsonb_build_object('parentId',current_setting('test.issue'),'status','resolved','message','Tenant cannot resolve landlord workflow')));raise exception 'FAIL: tenant status update';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',50000,'method','EFT','reference','PENDING-CLAIM','bankReference','TENANT-BANK','payer','Family contributor','paidOn',current_date,'allocations',jsonb_build_array(jsonb_build_object('period',to_char(current_date,'YYYY-MM'),'amountCents',50000))));
select id as pending from public.bp_payments where reference='PENDING-CLAIM' \gset
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.bp_action('review',jsonb_build_object('id',:'pending','confirm',true,'allocations','[]'::jsonb));
select public.bp_action('case',jsonb_build_object('eventId',gen_random_uuid(),'tenancyId',:'tid','kind','case_update','body',jsonb_build_object('parentId',:'issue','status','resolved','message','Explained agreement reference and charges')));
reset role;
do $$begin
 assert public.bp_rent_due(current_setting('test.tenancy')::uuid,date_trunc('month',current_date)::date)=170000,'Planned expiry does not erase charges; adjustment applied once';
 assert public.bp_rent_due(current_setting('test.tenancy')::uuid,date_trunc('month',current_date+interval '1 month')::date)=200000;
 assert public.bp_rent_due(current_setting('test.tenancy')::uuid,date_trunc('month',current_date-interval '2 months')::date)=150000,'Future rent change must not rewrite history';
end $$;
set local role authenticated;
select public.bp_action('close_tenancy',jsonb_build_object('tenancyId',:'tid','date',current_date-1,'note','Actual agreed handover, final charge checked'));
select public.bp_action('tenancy',jsonb_build_object('propertyId',:'prop','name','Next occupant','room',1,'start',current_date));
select public.bp_action('reverse_payment',jsonb_build_object('id',:'pay','reason','Actual bank reversal evidenced by BANK-REV-1800'));
select invitation as next_invitation from public.bp_tenancies where property_id=:'prop' and tenant_id is null and ended_on is null \gset
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select public.bp_action('join_rental',jsonb_build_object('invitation',:'next_invitation'));
do $$begin assert jsonb_array_length(public.bp_snapshot()->'tenancies')=2,'Tenant joins next rental and retains previous history';end $$;

reset role;
do $$begin assert (select state='reversed' and receipt_details->>'issuedCreditCents'='30000' from public.bp_payments where id=current_setting('test.payment')::uuid),'Reversal retains original receipt';assert public.bp_rent_due(current_setting('test.tenancy')::uuid,date_trunc('month',current_date+interval '1 month')::date)=0,'Actual handover stops later charges';end $$;
rollback;
\echo 'Research account checks passed: offline tenant, invitation claim, multi-month allocations, payer, credit, immutable receipt, dated rent, adjustments, deposit/interest/refund, inspections, queries, RLS and handover.'
