-- Synthetic agreements created before fixed policy; disposable test database only.
update public.bp_properties set due_day=7,security_deposit=200000 where id='70000000-0000-0000-0000-000000000002';
insert into public.bp_tenancies(id,property_id,room,starts,rent,due_day,record)
 values('c1000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000002',20,current_date-35,150000,7,'{"tenantName":"Old default deadline"}'),
 ('c1000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000002',21,current_date-35,150000,7,'{"tenantName":"Existing custom deadline"}'),
 ('c1000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000002',22,current_date-35,150000,7,'{"tenantName":"Paid old deadline"}'),
 ('c1000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000002',23,current_date-35,150000,7,'{"tenantName":"Ended agreement"}');
update public.bp_tenancies set record=record||jsonb_build_object('depositDueOn',starts+30,'depositDueNote','Existing agreed payment plan') where id='c1000000-0000-0000-0000-000000000002';
update public.bp_tenancies set ended_on=current_date-1 where id='c1000000-0000-0000-0000-000000000004';
insert into public.bp_rent_terms(tenancy_id,period,amount,due_day,evidence,actor)
 select id,date_trunc('month',starts)::date,150000,7,'Original agreed due day retained','70000000-0000-0000-0000-000000000001' from public.bp_tenancies where id::text like 'c1000000-%';
insert into public.bp_rent_terms values('c1000000-0000-0000-0000-000000000001',(date_trunc('month',current_date)+interval '2 months')::date,190000,12,'Future amount already agreed',now(),'70000000-0000-0000-0000-000000000001');
insert into public.bp_payments(id,tenancy_id,period,amount,method,reference,bank_reference,notes,paid_on,state,reviewed_at,payer,entered_by,receipt_details)
 values('c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001',date_trunc('month',current_date)::date,50000,'Cash','FIXED-HISTORY','','Existing receipt',current_date,'confirmed',now(),'Old default deadline','70000000-0000-0000-0000-000000000001','{"historical":"unchanged"}');
insert into public.bp_allocations values('c2000000-0000-0000-0000-000000000001',date_trunc('month',current_date)::date,50000);
insert into public.bp_case_records(tenancy_id,kind,body,actor) values('c1000000-0000-0000-0000-000000000003','deposit',jsonb_build_object('event','opening','date',current_date,'amountCents',200000,'reference','OLD-PAID-DEPOSIT'),'70000000-0000-0000-0000-000000000001');
