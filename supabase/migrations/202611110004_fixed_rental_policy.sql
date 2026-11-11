-- Fixed application policy: rent on the 1st; new tenants have ten calendar days
-- from actual move-in to pay the once-off deposit. No extra ten-day reminder delay.
-- Preserve charged-month rent terms and explicit pre-existing deposit agreements.
begin;
set local timezone='Africa/Johannesburg';

create or replace function public.bp_fixed_deposit_due_date(occupancy_start date,details jsonb) returns date
language plpgsql immutable set search_path=public,pg_temp as $$
declare due date;
begin
 if details->>'depositDeadlinePolicy'='move_in_plus_10' then return occupancy_start+10;end if;
 if details->>'depositDeadlinePolicy'='legacy_agreed' or length(trim(coalesce(details->>'depositDueNote','')))>0 then
  begin due:=(details->>'depositDueOn')::date;
  exception when invalid_datetime_format or datetime_field_overflow then due:=null;end;
  if due is not null and isfinite(due) then return due;end if;
 end if;
 return occupancy_start+10;
end $$;
revoke all on function public.bp_fixed_deposit_due_date(date,jsonb) from public,anon,authenticated;

-- Property defaults only affect new rentals; existing rent amounts are untouched.
update public.bp_properties set due_day=1 where due_day<>1;
create or replace function public.bp_first_day_property_policy() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin new.due_day:=1;return new;end $$;
revoke all on function public.bp_first_day_property_policy() from public,anon,authenticated;
drop trigger if exists bp_first_day_property_policy on public.bp_properties;
create trigger bp_first_day_property_policy before insert or update on public.bp_properties for each row execute function public.bp_first_day_property_policy();

-- Keep old charged-month due dates and amounts. Existing active rentals switch
-- to the first of the month from the next calendar month; future agreed rates stay.
do $$
declare t public.bp_tenancies;current_day integer;next_day integer;next_amount integer;next_month date:=(date_trunc('month',current_date)+interval '1 month')::date;
begin
 for t in select * from public.bp_tenancies where ended_on is null order by property_id,id for update loop
  insert into public.bp_rent_terms(tenancy_id,period,amount,due_day,evidence,actor)
   select t.id,date_trunc('month',t.starts)::date,t.rent,t.due_day,'Existing terms preserved before first-day payment policy',p.owner_id from public.bp_properties p where p.id=t.property_id
   and not exists(select 1 from public.bp_rent_terms where tenancy_id=t.id and period<=date_trunc('month',current_date)::date)
   on conflict(tenancy_id,period) do nothing;
  select due_day into current_day from public.bp_rent_terms where tenancy_id=t.id and period<=date_trunc('month',current_date)::date order by period desc limit 1;
  select amount,due_day into next_amount,next_day from public.bp_rent_terms where tenancy_id=t.id and period<=next_month order by period desc limit 1;
  next_amount:=coalesce(next_amount,t.rent);next_day:=coalesce(next_day,t.due_day);
  if coalesce(current_day,t.due_day)<>1 or exists(select 1 from public.bp_rent_terms where tenancy_id=t.id and period>=next_month and due_day<>1) then
   if not exists(select 1 from public.bp_rent_terms where tenancy_id=t.id and period=next_month) then
    insert into public.bp_rent_terms(tenancy_id,period,amount,due_day,evidence,actor)
     select t.id,next_month,next_amount,1,'Monthly rent due on the 1st from this month; existing rent amount retained',owner_id from public.bp_properties where id=t.property_id;
   end if;
   update public.bp_tenancies set record=record||jsonb_build_object('rentDuePolicyFrom',next_month) where id=t.id;
  end if;
  update public.bp_rent_terms set due_day=1 where tenancy_id=t.id and period>=next_month and due_day<>1;
  update public.bp_tenancies set due_day=1,record=record||jsonb_build_object('rentDuePolicy','first_of_month') where id=t.id;
  if coalesce((t.terms->>'depositCents')::integer,0)>coalesce((select sum((body->>'amountCents')::integer) from public.bp_case_records where tenancy_id=t.id and kind='deposit' and body->>'event' in ('received','opening')),0) then
   if length(trim(coalesce(t.record->>'depositDueNote','')))=0 and coalesce(t.record->>'depositDeadlinePolicy','')<>'legacy_agreed' then
    update public.bp_tenancies set record=record||jsonb_build_object('depositDeadlinePolicy','move_in_plus_10','depositDueOn',t.starts+10) where id=t.id;
   else
    update public.bp_tenancies set record=record||jsonb_build_object('depositDeadlinePolicy','legacy_agreed') where id=t.id and coalesce(record->>'depositDeadlinePolicy','')<>'move_in_plus_10';
   end if;
  end if;
 end loop;
end $$;

-- Alphabetically after the existing deposit trigger, so its old starts-date
-- default is replaced with the actual starts+10 policy on every new rental.
create or replace function public.bp_fixed_tenancy_policy() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if tg_op='INSERT' then
  new.due_day:=1;
  new.record:=coalesce(new.record,'{}')||jsonb_build_object('rentDuePolicy','first_of_month','depositDeadlinePolicy','move_in_plus_10','depositDueOn',new.starts+10);
 elsif old.record->>'depositDeadlinePolicy'='move_in_plus_10' then
  new.record:=new.record||jsonb_build_object('depositDeadlinePolicy','move_in_plus_10','depositDueOn',new.starts+10);
 elsif old.record->>'depositDeadlinePolicy'='legacy_agreed' then
  new.record:=new.record||jsonb_build_object('depositDeadlinePolicy','legacy_agreed','depositDueOn',old.record->'depositDueOn','depositDueNote',old.record->'depositDueNote');
 end if;
 return new;
end $$;
revoke all on function public.bp_fixed_tenancy_policy() from public,anon,authenticated;
drop trigger if exists bp_z_fixed_tenancy_policy on public.bp_tenancies;
create trigger bp_z_fixed_tenancy_policy before insert or update on public.bp_tenancies for each row execute function public.bp_fixed_tenancy_policy();

create or replace function public.bp_first_day_rent_term_policy() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if new.period>date_trunc('month',current_date)::date or exists(select 1 from public.bp_tenancies where id=new.tenancy_id and record->>'depositDeadlinePolicy'='move_in_plus_10' and new.period=date_trunc('month',starts)::date) then new.due_day:=1;end if;
 return new;
end $$;
revoke all on function public.bp_first_day_rent_term_policy() from public,anon,authenticated;
drop trigger if exists bp_first_day_rent_term_policy on public.bp_rent_terms;
create trigger bp_first_day_rent_term_policy before insert or update on public.bp_rent_terms for each row execute function public.bp_first_day_rent_term_policy();

create or replace function public.bp_generate_deposit_reminders(scope_user uuid,as_of date) returns integer
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare row record;due date;required_amount bigint;received_amount bigint;pending_amount bigint;outstanding_amount bigint;unreported_amount bigint;created integer:=0;affected integer;tenant_text text;owner_text text;
begin
 for row in select t.id,t.tenant_id,t.starts,t.ended_on,t.terms,t.record,t.room,p.owner_id,p.name as property_name
  from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id
  where scope_user is null or p.owner_id=scope_user or t.tenant_id=scope_user
  order by p.id,t.id for update of p,t loop
  due:=public.bp_fixed_deposit_due_date(row.starts,row.record);
  required_amount:=coalesce((row.terms->>'depositCents')::integer,0);
  select coalesce(sum((body->>'amountCents')::integer),0) into received_amount from public.bp_case_records where tenancy_id=row.id and kind='deposit' and body->>'event' in ('received','opening');
  select coalesce(sum(amount),0) into pending_amount from public.bp_deposit_payment_reports where tenancy_id=row.id and state='pending';
  outstanding_amount:=greatest(0,required_amount-received_amount);
  unreported_amount:=greatest(0,outstanding_amount-pending_amount);
  -- Old warnings become read when paid, covered by a report, returned, or rescheduled.
  update public.bp_notices set read=true where deposit_tenancy_id=row.id and not read and (
   row.ended_on is not null or required_amount<=0 or outstanding_amount=0 or deposit_due_on is distinct from due or as_of<due
   or (deposit_reminder_kind='payment' and unreported_amount=0)
   or (deposit_reminder_kind='review' and pending_amount=0));
  if row.ended_on is not null or required_amount<=0 or outstanding_amount=0 or as_of<due then continue;end if;
  if unreported_amount>0 then
   tenant_text:='Your security deposit record still shows R '||to_char(unreported_amount::numeric/100,'FM9999999990.00')||' to pay or report for room '||row.room||'. The deposit payment deadline was '||due||'. If you already paid, report the payment or contact your landlord.';
   if pending_amount>0 then tenant_text:=tenant_text||' R '||to_char(least(pending_amount,outstanding_amount)::numeric/100,'FM9999999990.00')||' has already been reported and is waiting for your landlord to check. Do not pay that reported amount again.';end if;
   if row.tenant_id is not null then
    insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
     values(row.tenant_id,'Security deposit still outstanding',tenant_text,row.id,due,'payment')
     on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
    get diagnostics affected=row_count;created:=created+affected;
    update public.bp_notices set message=tenant_text where user_id=row.tenant_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='payment';
   end if;
   owner_text:='Room '||row.room||' at '||row.property_name||' still has R '||to_char(unreported_amount::numeric/100,'FM9999999990.00')||' of the security deposit to pay or report. The agreed due date was '||due||'. Check any money already received before following up.';
   insert into public.bp_notices(user_id,title,message,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind)
    values(row.owner_id,'Security deposit follow-up',owner_text,row.id,due,'payment')
    on conflict(user_id,deposit_tenancy_id,deposit_due_on,deposit_reminder_kind) where deposit_tenancy_id is not null do nothing;
   get diagnostics affected=row_count;created:=created+affected;
   update public.bp_notices set message=owner_text where user_id=row.owner_id and deposit_tenancy_id=row.id and deposit_due_on=due and deposit_reminder_kind='payment';
  end if;
  if pending_amount>0 then
   owner_text:='A security deposit payment of R '||to_char(least(pending_amount,outstanding_amount)::numeric/100,'FM9999999990.00')||' for room '||row.room||' at '||row.property_name||' is waiting for your confirmation. Its deposit payment deadline has arrived. Check the cash or bank payment; do not ask the tenant to pay the reported amount again.';
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


-- Preserve all existing payment/report validation behind a fixed-policy facade.
do $$begin
 if to_regprocedure('public.bp_action_v8(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v8;end if;
 if to_regprocedure('public.bp_snapshot_v7()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v7;end if;
end $$;
revoke all on function public.bp_action_v8(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v7() from public,anon;
grant execute on function public.bp_snapshot_v7() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation='deposit_deadline' then raise exception 'New tenants have 10 calendar days from move-in to pay the once-off deposit. Its deadline is calculated automatically.';end if;
 if operation in ('property','rent_term') then args:=coalesce(args,'{}')||jsonb_build_object('dueDay',1);end if;
 return public.bp_action_v8(operation,args);
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v7();
 return s||jsonb_build_object('fixedRentalPolicyVersion',1,'rentDueDay',1,'depositPaymentDays',10);
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
