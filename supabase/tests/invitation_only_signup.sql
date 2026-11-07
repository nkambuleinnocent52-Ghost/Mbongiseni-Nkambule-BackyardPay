\set ON_ERROR_STOP on
begin;
set local role anon;
do $$begin assert public.bp_tenant_signup_mode()='invitation_only';end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Assigned rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('tenancy','{"propertyId":"70000000-0000-0000-0000-000000000002","name":"Assigned tenant","room":7,"start":"2026-01-15"}');
select id as tid,invitation as invite from public.bp_tenancies where room=7 \gset
select set_config('test.invitation_tid',:'tid',true),set_config('test.private_invite',:'invite',true);
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',50000,'method','Cash','reference','BEFORE-ACCOUNT','payer','Assigned tenant','paidOn','2026-01-15','received',true,'allocations',jsonb_build_array(jsonb_build_object('period','2026-01','amountCents',50000))));
reset role;
do $$declare meta jsonb;begin
 meta:=jsonb_build_object('name','Wrong room','role','tenant','phone','0722222222','code','BP-PRORATE','room','8');
 begin insert into auth.users values('90000000-0000-0000-0000-000000000011','public-claim@test.invalid',meta);raise exception 'FAIL: public property code claimed a room';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 meta:=meta||jsonb_build_object('code',current_setting('test.private_invite'),'room','8');
 begin insert into auth.users values('90000000-0000-0000-0000-000000000012','room-tamper@test.invalid',meta);raise exception 'FAIL: selected a room';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 assert not exists(select 1 from public.bp_profiles where id in ('90000000-0000-0000-0000-000000000011','90000000-0000-0000-0000-000000000012')),'Rejected signups leave no orphan profiles';
end $$;
-- A rental handed back cannot be connected using an old unclaimed invitation.
update public.bp_tenancies set ended_on='2026-01-31' where id=current_setting('test.invitation_tid')::uuid;
do $$begin
 begin insert into auth.users values('90000000-0000-0000-0000-000000000015','ended@test.invalid',jsonb_build_object('name','Ended rental','role','tenant','phone','0722222222','code',current_setting('test.private_invite')));raise exception 'FAIL: ended rental claimed';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
 assert not exists(select 1 from public.bp_profiles where id='90000000-0000-0000-0000-000000000015');
end $$;
update public.bp_tenancies set ended_on=null where id=current_setting('test.invitation_tid')::uuid;
insert into auth.users values('90000000-0000-0000-0000-000000000013','invited@test.invalid',jsonb_build_object('name','Connected tenant','role','tenant','phone','0722222222','code',:'invite'));
do $$begin
 assert (select tenant_id='90000000-0000-0000-0000-000000000013' and room=7 and starts='2026-01-15' and rent=150000 and (terms->>'depositCents')::integer=200000 from public.bp_tenancies where id=current_setting('test.invitation_tid')::uuid),'Claim uses the exact existing rental, terms and move-in';
 assert (select count(*)=1 from public.bp_payments where tenancy_id=current_setting('test.invitation_tid')::uuid),'Payment history retained';
 assert (select count(*)=1 from public.bp_tenancies where tenant_id='90000000-0000-0000-0000-000000000013'),'No additional room or rental created';
 begin insert into auth.users values('90000000-0000-0000-0000-000000000014','reused@test.invalid',jsonb_build_object('name','Reuse','role','tenant','phone','0722222222','code',current_setting('test.private_invite')));raise exception 'FAIL: reused invitation';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000013',true);
do $$begin assert jsonb_array_length(public.bp_snapshot()->'tenancies')=1;assert jsonb_array_length(public.bp_snapshot()->'payments')=1;end $$;
rollback;
\echo 'Invitation-only checks passed: property codes/room tampering rejected; exact landlord assignment and history retained; one-use claim and no orphan profiles.'
