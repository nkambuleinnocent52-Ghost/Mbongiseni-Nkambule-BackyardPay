-- Synthetic fixture before upgrade; disposable PostgreSQL only.
insert into auth.users values('70000000-0000-0000-0000-000000000001','proration-owner@test.invalid','{"name":"Owner","role":"landlord","phone":"0711111111"}');
insert into public.bp_properties(id,owner_id,name,address,code,rooms,rent,due_day) values('70000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000001','Existing property','1 Test Street','BP-PRORATE',30,150000,1);
insert into public.bp_tenancies(id,property_id,room,starts,rent,due_day,record) values('70000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000002',30,'2026-01-15',150000,1,'{"tenantName":"Existing tenant"}');
insert into public.bp_rent_terms values('70000000-0000-0000-0000-000000000003','2026-01-01',150000,1,'Old monthly terms',now(),'70000000-0000-0000-0000-000000000001');
