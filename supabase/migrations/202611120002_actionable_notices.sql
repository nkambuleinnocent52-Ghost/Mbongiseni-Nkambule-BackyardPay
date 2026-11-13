-- Typed notice destinations. Existing history is retained; ambiguous old notices
-- deliberately stay unlinked instead of guessing a tenant or payment.
begin;
alter table public.bp_notices add column if not exists target_kind text;
alter table public.bp_notices add column if not exists target_id uuid;
alter table public.bp_notices add column if not exists tenancy_id uuid references public.bp_tenancies(id);
alter table public.bp_notices add column if not exists route_request_id uuid;
create index if not exists bp_notice_route_request on public.bp_notices(route_request_id) where route_request_id is not null;

create or replace function public.bp_stamp_notice_route() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 -- Cron reminders have an explicit rental foreign key and no interactive request.
 if new.deposit_tenancy_id is not null and new.target_kind is null then
  new.target_kind:='rental';new.target_id:=new.deposit_tenancy_id;new.tenancy_id:=new.deposit_tenancy_id;
  new.route_request_id:=null;
  return new;
 end if;
 begin new.route_request_id:=nullif(current_setting('backyardpay.notice_request',true),'')::uuid;
 exception when invalid_text_representation then new.route_request_id:=null;end;
 return new;
end $$;
revoke all on function public.bp_stamp_notice_route() from public,anon,authenticated;
drop trigger if exists bp_notice_route_stamp on public.bp_notices;
create trigger bp_notice_route_stamp before insert on public.bp_notices for each row execute function public.bp_stamp_notice_route();
update public.bp_notices set target_kind='rental',target_id=deposit_tenancy_id,tenancy_id=deposit_tenancy_id
 where target_kind is null and deposit_tenancy_id is not null;

do $$begin
 if to_regprocedure('public.bp_action_before_notice_routes(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_before_notice_routes;end if;
 if to_regprocedure('public.bp_snapshot_before_notice_routes()') is null then alter function public.bp_snapshot() rename to bp_snapshot_before_notice_routes;end if;
end $$;
revoke all on function public.bp_action_before_notice_routes(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_before_notice_routes() from public,anon;
grant execute on function public.bp_snapshot_before_notice_routes() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare result jsonb;forward_args jsonb:=coalesce(args,'{}');request uuid:=gen_random_uuid();previous_request text;
 tid uuid;dest uuid;dest_kind text;t public.bp_tenancies;p public.bp_properties;
 pay public.bp_payments;dep public.bp_deposit_payment_reports;record public.bp_case_records;
 who text;actor_name text;identity text;purpose text;new_title text;new_text text;
 requested_status text;existing_status text;was_existing boolean:=false;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 -- The core command validates ownership and existing case permissions. Translate
 -- the extra acknowledgement state for that validation, then retain it in history.
 if operation='case' and args->>'kind'='case_update' then
  requested_status:=args->'body'->>'status';
  select body->>'status' into existing_status from public.bp_case_records where id=(args->>'eventId')::uuid and public.bp_sees_tenancy(tenancy_id);
  was_existing:=found;
  if was_existing and existing_status is distinct from requested_status then
   raise exception 'This update was already saved with another status. Refresh before adding a new update.';
  end if;
  if requested_status='acknowledged' then
   forward_args:=jsonb_set(forward_args,'{body,status}','"in_progress"'::jsonb);
  end if;
 end if;
 previous_request:=current_setting('backyardpay.notice_request',true);
 perform set_config('backyardpay.notice_request',request::text,true);
 result:=public.bp_action_before_notice_routes(operation,forward_args);
 perform set_config('backyardpay.notice_request',coalesce(previous_request,''),true);

 if operation in ('payment','review','allocate_credit','reverse_payment') then
  if operation='payment' then dest:=nullif(result->>'result','')::uuid;else dest:=(args->>'id')::uuid;end if;
  select * into pay from public.bp_payments where id=dest;
  if found then tid:=pay.tenancy_id;dest_kind:='rent_payment';purpose:='Rent';end if;
 elsif operation in ('deposit_report','deposit_review') then
  dest:=case when operation='deposit_report' then (args->>'eventId')::uuid else (args->>'id')::uuid end;
  select * into dep from public.bp_deposit_payment_reports where id=dest;
  if found then tid:=dep.tenancy_id;dest_kind:='deposit_report';purpose:='Security deposit';end if;
 elsif operation='case' then
  select * into record from public.bp_case_records where id=(args->>'eventId')::uuid;
  if found then
   tid:=record.tenancy_id;
   if record.kind in ('repair','query') then dest:=record.id;dest_kind:='issue';purpose:='Issue';
   elsif record.kind='case_update' then
    dest:=(record.body->>'parentId')::uuid;dest_kind:='issue';purpose:='Issue';
    if requested_status='acknowledged' and not was_existing then
     update public.bp_case_records set body=jsonb_set(body,'{status}','"acknowledged"'::jsonb)
      where id=record.id and actor=auth.uid();
    end if;
   else dest:=tid;dest_kind:='rental';purpose:=case when record.kind='deposit' then 'Security deposit' else 'Rental' end;
   end if;
  end if;
 elsif operation in ('agreement','acknowledge','rent_term','close_tenancy','reminder','deposit_update','deposit_deadline') then
  tid:=(args->>'tenancyId')::uuid;dest:=tid;dest_kind:='rental';
  purpose:=case when operation like 'deposit_%' then 'Security deposit' else 'Rental' end;
 elsif operation in ('tenancy','join_rental') then
  tid:=nullif(result->>'result','')::uuid;dest:=tid;dest_kind:='rental';purpose:='Rental';
 elsif operation='property_message' then
  dest:=(args->>'propertyId')::uuid;dest_kind:='property';purpose:='Property';
 end if;

 if tid is not null then
  select * into t from public.bp_tenancies where id=tid;
  select * into p from public.bp_properties where id=t.property_id;
  select name into who from public.bp_profiles where id=t.tenant_id;
  who:=coalesce(who,nullif(t.record->>'tenantName',''),'Tenant');
  identity:=who||' · Room '||t.room;
  select name into actor_name from public.bp_profiles where id=auth.uid();
  if dest_kind='rent_payment' then
   new_title:=case when pay.state='pending' then 'Rent payment to check' when pay.state='confirmed' then 'Rent payment confirmed' else 'Rent payment needs attention' end;
   new_text:=identity||' · Rent R '||to_char(pay.amount::numeric/100,'FM9999999990.00')||'. '||case when pay.state='pending' then 'Check the money received before confirming.' when pay.state='confirmed' then 'The confirmed payment and receipt are ready.' else coalesce(pay.reason,'Open the payment to read the reason.') end;
  elsif dest_kind='deposit_report' then
   -- Preserve familiar deposit titles while adding a precise destination.
   new_title:=case when dep.state='pending' then 'Deposit payment awaiting review' when dep.state='confirmed' then 'Security deposit payment confirmed' else 'Deposit payment needs attention' end;
   new_text:=identity||' · Security deposit R '||to_char(dep.amount::numeric/100,'FM9999999990.00')||'. '||case when dep.state='pending' then 'Check the money received before confirming.' when dep.state='confirmed' then 'The deposit was recorded separately from rent.' else coalesce(nullif(dep.reason,''),'Open the payment to read the reason.') end;
  elsif dest_kind='issue' then
   if record.kind='case_update' then
    new_title:=case requested_status when 'acknowledged' then 'Issue acknowledged' when 'in_progress' then 'Issue in progress' when 'resolved' then 'Issue resolved' else 'Issue reply' end;
    new_text:=identity||' · '||coalesce(actor_name,'Landlord or tenant')||': '||coalesce(record.body->>'message','Open the issue.');
   else
    new_title:=case when record.kind='query' then 'Account query submitted' else 'Problem reported' end;
    new_text:=identity||' · '||coalesce(nullif(record.body->>'location',''),'Location not specified')||': '||coalesce(record.body->>'description','Open the issue.');
   end if;
  elsif operation='rent_term' then
   new_title:='Rent change recorded';
   new_text:=identity||' · New monthly rent R '||to_char((args->>'amountCents')::numeric/100,'FM9999999990.00')||' from '||(args->>'period')||'. Due on the 1st. Open the rental for the recorded agreement.';
  end if;
 end if;
 update public.bp_notices set target_kind=coalesce(target_kind,dest_kind),target_id=coalesce(target_id,dest),tenancy_id=coalesce(tenancy_id,tid),
  title=coalesce(new_title,title),message=coalesce(new_text,case when identity is not null then identity||' · '||message else message end)
  where route_request_id=request;
 return result;
exception when others then
 perform set_config('backyardpay.notice_request',coalesce(previous_request,''),true);
 raise;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

-- Keep SECURITY INVOKER: the source query must obey notice recipient RLS.
create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_before_notice_routes();
 return s||jsonb_build_object('actionableNoticesVersion',1,'notices',coalesce((select jsonb_agg(jsonb_build_object(
  'id',id,'userId',user_id,'title',title,'message',message,'createdAt',created_at,'read',read,
  'targetKind',target_kind,'targetId',target_id,'tenancyId',tenancy_id) order by created_at desc,id)
  from public.bp_notices),'[]'::jsonb));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
