\set ON_ERROR_STOP on
begin;
do $$begin
 assert (select count(*)=1 from cron.job where jobname='backyardpay-deposit-reminders'),'Rerun scheduling keeps one named job';
 assert public.bp_deposit_reminder_scheduler_enabled(),'Exact active daily job must report enabled';
 assert (select schedule='0 6 * * *' and command='select public.bp_run_deposit_reminders();' from cron.job where jobname='backyardpay-deposit-reminders');
end $$;
update cron.job set active=false where jobname='backyardpay-deposit-reminders';
do $$begin assert not public.bp_deposit_reminder_scheduler_enabled(),'Disabled job is not enabled';end $$;
update cron.job set active=true,schedule='0 7 * * *' where jobname='backyardpay-deposit-reminders';
do $$begin assert not public.bp_deposit_reminder_scheduler_enabled(),'Wrong schedule is not enabled';end $$;
update cron.job set schedule='0 6 * * *' where jobname='backyardpay-deposit-reminders';
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Scheduled rooms","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":200000}');
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Offline tenant','room',26,'start',(now() at time zone 'Africa/Johannesburg')::date));
select id as tid,invitation as invite from public.bp_tenancies where room=26 \gset
select set_config('test.scheduled_tid',:'tid',true);
reset role;
insert into auth.users values('b1000000-0000-0000-0000-000000000003','scheduled-tenant@test.invalid',jsonb_build_object('name','Offline tenant','role','tenant','phone','0712222222','code',:'invite'));
update public.bp_tenancies set record=record||jsonb_build_object('depositDueOn',(now() at time zone 'Africa/Johannesburg')::date-10) where id=:'tid';
select set_config('request.jwt.claim.sub','',true);
-- Execute the stored job command with no signed-in app/session or snapshot call.
do $$declare command text;begin select j.command into command from cron.job j where jobname='backyardpay-deposit-reminders';execute command;execute command;end $$;
do $$begin
 assert (select count(*)=2 from public.bp_notices where deposit_tenancy_id=current_setting('test.scheduled_tid')::uuid),'Global job creates one tenant and one owner reminder without an app refresh';
 assert (select count(*)=1 from public.bp_notices where deposit_tenancy_id=current_setting('test.scheduled_tid')::uuid and user_id='b1000000-0000-0000-0000-000000000003');
 assert not exists(select 1 from public.bp_case_records where tenancy_id=current_setting('test.scheduled_tid')::uuid and kind='deposit'),'Reminder does not mark money paid';
 assert not exists(select 1 from public.bp_payments where tenancy_id=current_setting('test.scheduled_tid')::uuid),'Reminder does not create rent/penalties';
end $$;
rollback;
\echo 'Scheduler contract passed: named daily job configured once, exact active status, disabled/wrong schedule false, stored global command creates reminders without an app/session and no duplicate notices.'
