-- A 10-day application reminder, not a statutory grace period or enforcement action.
begin;
alter table public.bp_notices add column if not exists deposit_tenancy_id uuid references public.bp_tenancies(id);
alter table public.bp_notices add column if not exists deposit_due_on date;
alter table public.bp_notices add column if not exists deposit_reminder_kind text check(deposit_reminder_kind in ('payment','review'));
create unique index if not exists bp_deposit_reminder_once on public.bp_notices(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null;

-- Private worker: the scheduled job processes all rentals; the authenticated
-- wrapper supplies only its caller's scope. A caller cannot choose another user/date.
create or replace function public.bp_generate_deposit_reminders(scope_user uuid,as_of date) returns integer
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare row record;due date;required_amount bigint;received_amount bigint;pending_amount bigint;outstanding_amount bigint;unreported_amount bigint;created integer:=0;affected integer;tenant_text text;owner_text text;
begin
 for row in select t.id,t.tenant_id,t.starts,t.ended_on,t.terms,t.record,t.room,p.owner_id,p.name as property_name
  from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id
  where scope_user is null or p.owner_id=scope_user or t.tenant_id=scope_user
  order by p.id,t.id for update of p,t loop
  due:=row.starts;
  begin if nullif(row.record->>'depositDueOn','') is not null then due:=(row.record->>'depositDueOn')::date;end if;
  exception when invalid_datetime_format or datetime_field_overflow then due:=row.starts;end;
  if not isfinite(due) then due:=row.starts;end if;
  required_amount:=coalesce((row.terms->>'depositCents')::integer,0);
  select coalesce(sum((body->>'amountCents')::integer),0) into received_amount from public.bp_case_records where tenancy_id=row.id and kind='deposit' and body->>'event' in ('received','opening');
  select coalesce(sum(amount),0) into pending_amount from public.bp_deposit_payment_reports where tenancy_id=row.id and state='pending';
  outstanding_amount:=greatest(0,required_amount-received_amount);
  unreported_amount:=greatest(0,outstanding_amount-pending_amount);
  -- Old warnings become read when paid, covered by a report, returned, or rescheduled.
  update public.bp_notices set read=true where deposit_tenancy_id=row.id and not read and (
   row.ended_on is not null or required_amount<=0 or outstanding_amount=0 or deposit_due_on is distinct from due or as_of<due+10
   or (deposit_reminder_kind='payment' and unreported_amount=0)
   or (deposit_reminder_kind='review' and pending_amount=0));
  if row.ended_on is not null or required_amount<=0 or outstanding_amount=0 or as_of<due+10 then continue;end if;
  if unreported_amount>0 then
   tenant_text:='Your security deposit record still shows R '||to_char(unreported_amount::numeric/100,'FM9999999990.00')||' to pay or report for room '||row.room||'. The agreed due date was '||due||', at least 10 days ago. If you already paid, report the payment or contact your landlord.';
   if pending_amount>0 then tenant_text:=tenant_text||' R '||to_char(least(pending_amount,outstanding_amount)::numeric/100,'FM9999999990.00')||' has already been reported and is waiting for your landlord to check. Do not pay that reported amount again.';end if;
   if row.tenant_id is not null then
    insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
     values(row.tenant_id,'Security deposit still outstanding',tenant_text,row.id,due,'payment')
     on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
    get diagnostics affected=row_count;created:=created+affected;
    update public.bp_notices set message=tenant_text where user_id=row.tenant_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='payment';
   end if;
   owner_text:='Room '||row.room||' at '||row.property_name||' still has R '||to_char(unreported_amount::numeric/100,'FM9999999990.00')||' of the security deposit to pay or report. The agreed due date was '||due||', at least 10 days ago. Check any money already received before following up.';
   insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
    values(row.owner_id,'Security deposit follow-up',owner_text,row.id,due,'payment')
    on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
   get diagnostics affected=row_count;created:=created+affected;
   update public.bp_notices set message=owner_text where user_id=row.owner_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='payment';
  end if;
  if pending_amount>0 then
   owner_text:='A security deposit payment of R '||to_char(least(pending_amount,outstanding_amount)::numeric/100,'FM9999999990.00')||' for room '||row.room||' at '||row.property_name||' is waiting for your confirmation. The agreed deposit due date was at least 10 days ago. Check the cash or bank payment; do not ask the tenant to pay the reported amount again.';
   insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
    values(row.owner_id,'Check reported deposit payment',owner_text,row.id,due,'review')
    on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
   get diagnostics affected=row_count;created:=created+affected;
   update public.bp_notices set message=owner_text where user_id=row.owner_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='review';
  end if;
 end loop;
 return created;
end $$;
revoke all on function public.bp_generate_deposit_reminders(uuid,date) from public,anon,authenticated;

create or replace function public.bp_check_deposit_reminders() returns integer
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.bp_profiles where id=auth.uid()) then raise exception 'Sign in to check your deposit reminders.';end if;
 return public.bp_generate_deposit_reminders(auth.uid(),current_date);
end $$;
revoke all on function public.bp_check_deposit_reminders() from public,anon;
grant execute on function public.bp_check_deposit_reminders() to authenticated;

create or replace function public.bp_run_deposit_reminders() returns integer
language sql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
 select public.bp_generate_deposit_reminders(null,current_date);
$$;
revoke all on function public.bp_run_deposit_reminders() from public,anon,authenticated;

create or replace function public.bp_deposit_reminder_scheduler_enabled() returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare enabled boolean;
begin
 if to_regclass('cron.job') is null then return false;end if;
 execute 'select exists(select 1 from cron.job where jobname=$1 and active and schedule=$2 and command=$3)'
  into enabled using 'backyardpay-deposit-reminders','0 6 * * *','select public.bp_run_deposit_reminders();';
 return coalesce(enabled,false);
end $$;
revoke all on function public.bp_deposit_reminder_scheduler_enabled() from public,anon;
grant execute on function public.bp_deposit_reminder_scheduler_enabled() to authenticated;

-- Supabase pg_cron uses UTC: 06:00 UTC is 08:00 South African time.
-- A stock PostgreSQL test database may not provide this optional extension.
do $$begin
 if not exists(select 1 from pg_extension where extname='pg_cron') and exists(select 1 from pg_available_extensions where name='pg_cron') then
  begin create extension if not exists pg_cron;
  exception when insufficient_privilege or object_not_in_prerequisite_state or feature_not_supported or undefined_file or raise_exception then
   raise notice 'Deposit reminders installed, but pg_cron could not be enabled: %. Enable Cron in Supabase to send scheduled reminders while the app is closed.',sqlerrm;
  end;
 end if;
 if to_regclass('cron.job') is not null then
  begin
   execute 'select cron.schedule($1,$2,$3)' using 'backyardpay-deposit-reminders','0 6 * * *','select public.bp_run_deposit_reminders();';
  exception when insufficient_privilege or undefined_function then
   raise notice 'Deposit reminders installed, but the daily job could not be scheduled: %. Enable/configure Cron in Supabase.',sqlerrm;
  end;
 else
  raise notice 'Deposit reminders installed. Cron is not active: reminders will be checked on signed-in app refresh until Supabase Cron is enabled and the update is run again.';
 end if;
end $$;

do $$begin
 if to_regprocedure('public.bp_action_v7(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v7;end if;
 if to_regprocedure('public.bp_snapshot_v6()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v6;end if;
end $$;
revoke all on function public.bp_action_v7(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v6() from public,anon;
grant execute on function public.bp_snapshot_v6() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare t public.bp_tenancies;p public.bp_properties;due date;note text;r jsonb;
begin
 if operation='deposit_deadline' then
  if not exists(select 1 from public.bp_profiles where id=auth.uid() and role='landlord') then raise exception 'Only the landlord can record the agreed deposit due date.';end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
  select * into t from public.bp_tenancies where id=(args->>'tenancyId')::uuid;
  select * into p from public.bp_properties where id=t.property_id and owner_id=auth.uid() for update;
  if not found then raise exception 'Rental unavailable.';end if;
  select * into t from public.bp_tenancies where id=t.id for update;
  begin due:=(args->>'date')::date;exception when invalid_datetime_format or datetime_field_overflow then raise exception 'Enter a valid agreed deposit due date.';end;
  note:=trim(coalesce(args->>'note',''));
  if due is null or not isfinite(due) or due<'2020-01-01' or due>'2100-12-31' or length(note) not between 3 and 1500 then raise exception 'Record the actual agreed due date and a short agreement/payment-plan explanation.';end if;
  if t.record->>'depositDueOn'=due::text and t.record->>'depositDueNote'=note then return jsonb_build_object('result',t.id);end if;
  update public.bp_tenancies set record=record||jsonb_build_object('depositDueOn',due,'depositDueNote',note) where id=t.id;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','deposit_deadline','date',due,'note',note),auth.uid());
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Deposit due date updated','Your agreed security deposit due date is '||due||'. '||note);end if;
  r:=jsonb_build_object('result',t.id);
 else r:=public.bp_action_v7(operation,args);
 end if;
 -- The client fetches a new snapshot in a separate RPC after a command.
 -- Do not lock all owner properties while this action still holds one property.
 return r;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

-- The snapshot remains SECURITY INVOKER; do not bypass RLS on its original reads.
create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 perform public.bp_check_deposit_reminders();
 s:=public.bp_snapshot_v6();
 return s||jsonb_build_object('depositRemindersVersion',1,'depositReminderScheduler',public.bp_deposit_reminder_scheduler_enabled());
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
