-- Existing BackyardPay 1.4.0 installation: additive review update.
-- Optional Login ID stays disabled until its server endpoint is deployed and explicitly enabled.

-- 202611120001_agreement_defaults.sql
-- Shared property terms are entered once and copied into each new rental.
-- Historic rental particulars remain a snapshot, not a live mutable template.
begin;
create table if not exists public.bp_property_agreements (
 property_id uuid primary key references public.bp_properties(id) on delete cascade,
 details jsonb not null default '{}'::jsonb,
 history jsonb not null default '[]'::jsonb,
 updated_at timestamptz not null default now()
);
alter table public.bp_property_agreements enable row level security;
revoke all on public.bp_property_agreements from anon,authenticated;
grant select on public.bp_property_agreements to authenticated;
drop policy if exists bp_property_agreement_read on public.bp_property_agreements;
create policy bp_property_agreement_read on public.bp_property_agreements for select to authenticated using(public.bp_owns(property_id));

do $$begin
 if to_regprocedure('public.bp_action_before_agreement_defaults(text,jsonb)') is null then
  alter function public.bp_action(text,jsonb) rename to bp_action_before_agreement_defaults;
 end if;
 if to_regprocedure('public.bp_snapshot_before_agreement_defaults()') is null then
  alter function public.bp_snapshot() rename to bp_snapshot_before_agreement_defaults;
 end if;
end $$;
revoke all on function public.bp_action_before_agreement_defaults(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_before_agreement_defaults() from public,anon;
grant execute on function public.bp_snapshot_before_agreement_defaults() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare p public.bp_properties;t public.bp_tenancies;template public.bp_property_agreements;
 body jsonb;key text;result jsonb;tid uuid;new_amount integer;prior_notice_ids uuid[]:=array[]::uuid[];
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation='property_agreement' then
  select * into p from public.bp_properties where id=(args->>'propertyId')::uuid and owner_id=auth.uid() for update;
  if not found then raise exception 'Property unavailable.';end if;
  body:=coalesce(args->'details','{}');
  if jsonb_typeof(body)<>'object' then raise exception 'Check the property terms.';end if;
  foreach key in array array['landlordAddress','authority','sharedFacilities','paymentInstructions','noticeTerms','escalationTerms','otherCharges','utilities','houseRules'] loop
   if jsonb_typeof(body->key)<>'string' or length(trim(coalesce(body->>key,''))) not between 1 and 1500 then
    raise exception 'Complete the shared property terms; enter None where it does not apply.';
   end if;
  end loop;
  if length(body->>'utilities')>1000 then raise exception 'Utility instructions may use up to 1000 characters.';end if;
  select jsonb_object_agg(k,trim(body->>k)) into body from unnest(array['landlordAddress','authority','sharedFacilities','paymentInstructions','noticeTerms','escalationTerms','otherCharges','utilities','houseRules']) k;
  insert into public.bp_property_agreements(property_id,details) values(p.id,body)
   on conflict(property_id) do update set history=bp_property_agreements.history||jsonb_build_array(jsonb_build_object('details',bp_property_agreements.details,'recordedAt',bp_property_agreements.updated_at)),details=excluded.details,updated_at=now();
  return jsonb_build_object('result',p.id);
 end if;
 if operation='agreement' then
  select * into t from public.bp_tenancies where id=(args->>'tenancyId')::uuid;
  if not found or not public.bp_owns(t.property_id) then raise exception 'Rental unavailable.';end if;
  perform 1 from public.bp_properties where id=t.property_id for update;
  select * into t from public.bp_tenancies where id=t.id for update;
  if (args->>'start')::date is distinct from t.starts then raise exception 'Move-in date is fixed from tenant onboarding.';end if;
  if t.terms->>'depositCents' is not null and (args->>'depositCents')::integer is distinct from (t.terms->>'depositCents')::integer then
   raise exception 'The security deposit is fixed from tenant onboarding. Record received payments and returns separately.';
  end if;
 end if;
 if operation='rent_term' then
  select coalesce(array_agg(id),array[]::uuid[]) into prior_notice_ids from public.bp_notices where title='Dated rent change recorded';
 end if;
 result:=public.bp_action_before_agreement_defaults(operation,args);
 if operation='tenancy' then
  tid:=(result->>'result')::uuid;
  select * into t from public.bp_tenancies where id=tid;
  select * into template from public.bp_property_agreements where property_id=t.property_id;
  if found then
   body:=template.details-'utilities'-'houseRules';
   update public.bp_tenancies set record=body||record||jsonb_build_object('propertyTermsCopiedAt',template.updated_at),terms=terms||jsonb_build_object('utilities',template.details->>'utilities','houseRules',template.details->>'houseRules') where id=tid;
  end if;
 elsif operation='rent_term' then
  select * into t from public.bp_tenancies where id=(args->>'tenancyId')::uuid;
  new_amount:=(args->>'amountCents')::integer;
  update public.bp_notices set message='Room '||t.room||': new rent R '||to_char(new_amount::numeric/100,'FM9999999990.00')||' per month from '||(args->>'period')||'. Rent remains due on the 1st. Reference: '||left(trim(args->>'evidence'),1000)
   where user_id=t.tenant_id and title='Dated rent change recorded' and not(id=any(prior_notice_ids));
 end if;
 return result;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_before_agreement_defaults();
 return s||jsonb_build_object('agreementDefaultsVersion',1,'propertyAgreements',coalesce((select jsonb_agg(jsonb_build_object('propertyId',property_id,'details',details,'updatedAt',updated_at)) from public.bp_property_agreements),'[]'::jsonb));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;


-- 202611120002_actionable_notices.sql
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


-- 202611120003_login_ids.sql
-- Optional Login ID sign-in. This is an identifier, not another password/factor.
-- Apply after the ordinary app updates. Email sign-in keeps working without it.
begin;
create table if not exists public.bp_login_ids (
  user_id uuid primary key references public.bp_profiles(id) on delete cascade,
  login_id text not null unique check(login_id ~ '^[1-9][0-9]{8}$')
);
create table if not exists public.bp_login_id_config (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false
);
insert into public.bp_login_id_config(singleton,enabled) values(true,false) on conflict do nothing;
create table if not exists public.bp_login_id_attempts (
  bucket text primary key,
  window_started timestamptz not null,
  attempts integer not null check(attempts>0)
);
alter table public.bp_login_ids enable row level security;
alter table public.bp_login_id_config enable row level security;
alter table public.bp_login_id_attempts enable row level security;
revoke all on public.bp_login_ids,public.bp_login_id_config,public.bp_login_id_attempts from public,anon,authenticated;

create or replace function public.bp_assign_login_id() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare candidate text;
begin
  if exists(select 1 from public.bp_login_ids where user_id=new.id) then return new; end if;
  loop
    -- Nine random digits, checked unique. It is deliberately not a secret.
    candidate:=(100000000+floor(random()*900000000))::bigint::text;
    begin
      insert into public.bp_login_ids(user_id,login_id) values(new.id,candidate);
      exit;
    exception when unique_violation then
      if exists(select 1 from public.bp_login_ids where user_id=new.id) then exit; end if;
    end;
  end loop;
  return new;
end $$;
revoke all on function public.bp_assign_login_id() from public,anon,authenticated;
drop trigger if exists bp_profile_login_id on public.bp_profiles;
create trigger bp_profile_login_id after insert on public.bp_profiles for each row execute function public.bp_assign_login_id();
do $$
declare item record; candidate text;
begin
 for item in select id from public.bp_profiles where id not in(select user_id from public.bp_login_ids) loop
  loop
   candidate:=(100000000+floor(random()*900000000))::bigint::text;
   begin
    insert into public.bp_login_ids(user_id,login_id) values(item.id,candidate);exit;
   exception when unique_violation then null;
   end;
  end loop;
 end loop;
end $$;

create or replace function public.bp_login_id_enabled() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce((select enabled from public.bp_login_id_config where singleton),false)
$$;
revoke all on function public.bp_login_id_enabled() from public;
grant execute on function public.bp_login_id_enabled() to anon,authenticated,service_role;
create or replace function public.bp_my_login_id() returns text
language sql stable security definer set search_path=public,pg_temp as $$
 select login_id from public.bp_login_ids where user_id=auth.uid() and public.bp_login_id_enabled()
$$;
revoke all on function public.bp_my_login_id() from public,anon;
grant execute on function public.bp_my_login_id() to authenticated;

-- The Edge Function alone may resolve an ID. Never expose email resolution to
-- anon/authenticated: the password must be verified by Supabase Auth first.
create or replace function public.bp_begin_login_id_attempt(requested_id text,client_hash text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare k text; threshold integer; total integer; email_address text;
begin
 if not public.bp_login_id_enabled() then return jsonb_build_object('allowed',false); end if;
 if requested_id !~ '^[1-9][0-9]{8}$' or client_hash !~ '^[a-f0-9]{64}$' then return jsonb_build_object('allowed',false); end if;
 -- Atomic upserts make limits shared by concurrent function instances. Global
 -- capacity also bounds anonymous ID spraying when no reliable IP is supplied.
 foreach k in array array['global','id:'||requested_id,'ip:'||client_hash] loop
  threshold:=case when k='global' then 1000 when left(k,3)='id:' then 10 else 60 end;
  insert into public.bp_login_id_attempts(bucket,window_started,attempts)
  values(k,now(),1)
  on conflict(bucket) do update set
   attempts=case when bp_login_id_attempts.window_started<=now()-interval '10 minutes' then 1 else bp_login_id_attempts.attempts+1 end,
   window_started=case when bp_login_id_attempts.window_started<=now()-interval '10 minutes' then now() else bp_login_id_attempts.window_started end
  returning attempts into total;
  if total>threshold then return jsonb_build_object('allowed',false); end if;
 end loop;
 select p.email into email_address from public.bp_login_ids l join public.bp_profiles p on p.id=l.user_id where l.login_id=requested_id;
 delete from public.bp_login_id_attempts where window_started<now()-interval '1 day' and bucket<>'global';
 return jsonb_build_object('allowed',true,'email',email_address);
end $$;
revoke all on function public.bp_begin_login_id_attempt(text,text) from public,anon,authenticated;
grant execute on function public.bp_begin_login_id_attempt(text,text) to service_role;

do $$ begin
 if to_regprocedure('public.bp_snapshot_before_login_ids()') is null then
  alter function public.bp_snapshot() rename to bp_snapshot_before_login_ids;
 end if;
end $$;
create or replace function public.bp_snapshot() returns jsonb
language sql security invoker set search_path=public,pg_temp as $$
 select public.bp_snapshot_before_login_ids() || jsonb_build_object(
  'loginIdsVersion',1,'loginIdsEnabled',public.bp_login_id_enabled(),
  'currentLoginId',public.bp_my_login_id())
$$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;


-- 202611120004_payment_intent.sql
-- Preserve the tenant's proposed rent months when the landlord confirms receipt.
-- This adds no charge/payment and does not rewrite existing allocations/receipts.
begin;
do $$begin
 if to_regprocedure('public.bp_action_before_payment_intent(text,jsonb)') is null then
  alter function public.bp_action(text,jsonb) rename to bp_action_before_payment_intent;
 end if;
 if to_regprocedure('public.bp_snapshot_before_payment_intent()') is null then
  alter function public.bp_snapshot() rename to bp_snapshot_before_payment_intent;
 end if;
end $$;
revoke all on function public.bp_action_before_payment_intent(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_before_payment_intent() from public,anon;
grant execute on function public.bp_snapshot_before_payment_intent() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare pay public.bp_payments; owner_id uuid; proposed jsonb; requested jsonb; part jsonb;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation='review' and coalesce((args->>'confirm')::boolean,false) then
  -- Match the existing mutation lock order: user, property, then rental/payment.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
  select * into pay from public.bp_payments where id=(args->>'id')::uuid;
  if not found then raise exception 'Payment unavailable.';end if;
  select p.owner_id into owner_id from public.bp_properties p
   join public.bp_tenancies t on t.property_id=p.id where t.id=pay.tenancy_id for update of p;
  if owner_id is distinct from auth.uid() or not exists(select 1 from public.bp_profiles where id=auth.uid() and role='landlord') then
   raise exception 'Only the linked landlord can confirm this rent payment.';
  end if;
  select * into pay from public.bp_payments where id=pay.id for update;
  if pay.state<>'pending' then raise exception 'This payment has already been reviewed.';end if;
  select coalesce(jsonb_agg(jsonb_build_object('period',to_char(a.period,'YYYY-MM'),'amountCents',a.amount) order by a.period,a.amount),'[]'::jsonb)
   into proposed from public.bp_allocations a where a.payment_id=pay.id;
  if args ? 'allocations' then
   if jsonb_typeof(args->'allocations') is distinct from 'array' or jsonb_array_length(args->'allocations')>120 then
    raise exception 'Provide a valid rent-month list.';
   end if;
   for part in select value from jsonb_array_elements(args->'allocations') loop
    if jsonb_typeof(part) is distinct from 'object' or coalesce(part->>'period','') !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
     or coalesce(part->>'amountCents','') !~ '^[0-9]+$' then raise exception 'Provide a valid rent-month list.';end if;
   end loop;
   select coalesce(jsonb_agg(jsonb_build_object('period',e->>'period','amountCents',(e->>'amountCents')::integer) order by e->>'period',(e->>'amountCents')::integer),'[]'::jsonb)
    into requested from jsonb_array_elements(args->'allocations') e;
   if requested<>proposed then
    raise exception 'Confirm the tenant''s reported rent months unchanged. If they are wrong, reject with a reason and ask the tenant to submit the correction.';
   end if;
  end if;
  -- Older clients without an allocation argument confirm the saved proposal.
  args:=args||jsonb_build_object('allocations',proposed);
 end if;
 return public.bp_action_before_payment_intent(operation,args);
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
begin
 return public.bp_snapshot_before_payment_intent()||jsonb_build_object('paymentIntentVersion',1);
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;
