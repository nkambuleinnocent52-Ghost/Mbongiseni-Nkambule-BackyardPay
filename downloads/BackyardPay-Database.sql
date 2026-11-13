-- New Supabase project only: complete ordered schema.
-- Existing 1.4.0 installations should use BackyardPay-Review-Update.sql instead.

-- 202610240001_backyardpay.sql
-- BackyardPay: run this complete file in the new project's SQL editor.
-- No passwords, service-role keys, or sample users are stored here.
begin;
create table if not exists public.bp_profiles (
 id uuid primary key references auth.users(id),
 role text not null check(role in ('landlord','tenant')),
 name text not null check(length(name) between 2 and 80),
 email text not null, phone text not null check(phone ~ '^\+?[0-9 ()-]{7,20}$')
);
create table if not exists public.bp_properties (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.bp_profiles(id),
 code text not null unique default ('BP-' || upper(replace(gen_random_uuid()::text,'-',''))),
 name text not null check(length(name) between 2 and 100),
 address text not null check(length(address) between 3 and 250),
 suburb text not null default '' check(length(suburb)<=100), city text not null default '' check(length(city)<=100),
 postal_code text not null default '' check(postal_code='' or postal_code ~ '^[0-9]{4}$'),
 rooms integer not null check(rooms between 1 and 999), rent integer not null check(rent>0),
 due_day integer not null check(due_day between 1 and 28),
 latitude double precision check(latitude between -90 and 90), longitude double precision check(longitude between -180 and 180)
);
create table if not exists public.bp_tenancies (
 id uuid primary key default gen_random_uuid(), property_id uuid not null references public.bp_properties(id),
 tenant_id uuid not null references public.bp_profiles(id), room integer not null check(room>0),
 starts date not null, ends date check(ends>=starts), rent integer not null check(rent>0), due_day integer not null check(due_day between 1 and 28),
 terms jsonb not null default '{}', acknowledged_at timestamptz
);
create table if not exists public.bp_payments (
 id uuid primary key default gen_random_uuid(), tenancy_id uuid not null references public.bp_tenancies(id),
 period date not null check(extract(day from period)=1), amount integer not null check(amount>0),
 method text not null check(method in ('Cash','EFT','PayShap','Other')),
 reference text not null check(length(reference) between 1 and 80), bank_reference text not null default '' check(length(bank_reference)<=100),
 notes text not null default '' check(length(notes)<=500), paid_on date not null,
 submitted_at timestamptz not null default now(), state text not null default 'pending' check(state in ('pending','confirmed','rejected')),
 reason text, reviewed_at timestamptz,
 check(method not in ('EFT','PayShap') or length(bank_reference)>0)
);
create unique index if not exists bp_payment_reference on public.bp_payments(lower(reference));
create table if not exists public.bp_notices (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.bp_profiles(id),
 title text not null, message text not null, created_at timestamptz not null default now(), read boolean not null default false
);
create index if not exists bp_property_owner on public.bp_properties(owner_id);
create index if not exists bp_tenancy_property on public.bp_tenancies(property_id);
create index if not exists bp_tenancy_tenant on public.bp_tenancies(tenant_id);
create index if not exists bp_payment_tenancy on public.bp_payments(tenancy_id,period);
create index if not exists bp_notice_user on public.bp_notices(user_id);

-- RLS and explicit grants: even API clients cannot bypass the command checks.
alter table public.bp_profiles enable row level security;
alter table public.bp_properties enable row level security;
alter table public.bp_tenancies enable row level security;
alter table public.bp_payments enable row level security;
alter table public.bp_notices enable row level security;
revoke all on public.bp_profiles,public.bp_properties,public.bp_tenancies,public.bp_payments,public.bp_notices from anon,authenticated;

-- Internal authorization helpers. Never callable through the public API.
create or replace function public.bp_owns(pid uuid) returns boolean language sql stable security definer set search_path = public,pg_temp as $$
 select exists(select 1 from public.bp_properties where id=pid and owner_id=auth.uid());
$$;
create or replace function public.bp_sees(pid uuid) returns boolean language sql stable security definer set search_path = public,pg_temp as $$
 select public.bp_owns(pid) or exists(select 1 from public.bp_tenancies where property_id=pid and tenant_id=auth.uid());
$$;
create or replace function public.bp_sees_tenancy(tid uuid) returns boolean language sql stable security definer set search_path = public,pg_temp as $$
 select exists(select 1 from public.bp_tenancies where id=tid and (tenant_id=auth.uid() or public.bp_owns(property_id)));
$$;
drop policy if exists bp_property_read on public.bp_properties;
create policy bp_property_read on public.bp_properties for select to authenticated using(public.bp_sees(id));
drop policy if exists bp_tenancy_read on public.bp_tenancies;
create policy bp_tenancy_read on public.bp_tenancies for select to authenticated using(tenant_id=auth.uid() or public.bp_owns(property_id));
drop policy if exists bp_payment_read on public.bp_payments;
create policy bp_payment_read on public.bp_payments for select to authenticated using(public.bp_sees_tenancy(tenancy_id));
drop policy if exists bp_notice_read on public.bp_notices;
create policy bp_notice_read on public.bp_notices for select to authenticated using(user_id=auth.uid());
drop policy if exists bp_profile_read on public.bp_profiles;
create policy bp_profile_read on public.bp_profiles for select to authenticated using(
 id=auth.uid() or exists(select 1 from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id
 where (t.tenant_id=bp_profiles.id and p.owner_id=auth.uid()) or (p.owner_id=bp_profiles.id and t.tenant_id=auth.uid()))
);
-- Helpers must be executable for RLS, but expose only booleans about the caller's access.
grant execute on function public.bp_owns(uuid),public.bp_sees(uuid),public.bp_sees_tenancy(uuid) to authenticated;
revoke execute on function public.bp_owns(uuid),public.bp_sees(uuid),public.bp_sees_tenancy(uuid) from public,anon;
grant select on public.bp_profiles,public.bp_properties,public.bp_tenancies,public.bp_payments,public.bp_notices to authenticated;

-- Signup and tenant allocation are atomic with Auth signup. Property-row locking
-- prevents concurrent signups claiming the same room. No public property lookup.
create or replace function public.bp_on_signup() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare m jsonb := new.raw_user_meta_data; p public.bp_properties; r integer; tid uuid;
begin
 if coalesce(m->>'role','') not in ('landlord','tenant') then raise exception 'Choose a valid account role.'; end if;
 insert into public.bp_profiles(id,role,name,email,phone) values(new.id,m->>'role',trim(m->>'name'),new.email,trim(m->>'phone'));
 if m->>'role'='tenant' then
   select * into p from public.bp_properties where code=upper(trim(m->>'code')) for update;
   if not found then raise exception 'Ask your landlord for a valid property code.'; end if;
   if coalesce(m->>'room','') !~ '^[1-9][0-9]{0,2}$' then raise exception 'Enter a valid room number.'; end if;
   r := (m->>'room')::integer;
   if r>p.rooms or exists(select 1 from public.bp_tenancies where property_id=p.id and room=r and (ends is null or ends>=current_date)) then
     raise exception 'The room is unavailable. Ask your landlord to check it.';
   end if;
   insert into public.bp_tenancies(property_id,tenant_id,room,starts,rent,due_day)
     values(p.id,new.id,r,current_date,p.rent,p.due_day) returning id into tid;
   insert into public.bp_notices(user_id,title,message) values(p.owner_id,'New tenant',trim(m->>'name') || ' joined ' || p.name || ', room ' || r || '.');
 end if;
 return new;
end $$;
revoke execute on function public.bp_on_signup() from public,anon,authenticated;
drop trigger if exists backyardpay_signup on auth.users;
create trigger backyardpay_signup after insert on auth.users for each row execute function public.bp_on_signup();

-- Snapshot respects RLS as the authenticated caller; no password hashes exist in these tables.
create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.'; end if;
 if not exists(select 1 from public.bp_profiles where id=auth.uid()) then raise exception 'This account has no BackyardPay profile. Contact support.'; end if;
 select jsonb_build_object('version',1,'session',auth.uid(),
 'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'phone',phone,'email',email,'role',role,'salt','','passwordHash','')) from public.bp_profiles),'[]'),
 'properties',coalesce((select jsonb_agg(jsonb_build_object('id',id,'landlordId',owner_id,'name',name,'address',address,'suburb',suburb,'city',city,'postalCode',postal_code,'code',code,'rooms',rooms,'rentCents',rent,'dueDay',due_day,'latitude',latitude,'longitude',longitude)) from public.bp_properties),'[]'),
 'tenancies',coalesce((select jsonb_agg(terms || jsonb_build_object('id',id,'userId',tenant_id,'propertyId',property_id,'room',room::text,'startPeriod',to_char(starts,'YYYY-MM'),'rentCents',rent,'dueDay',due_day,'leaseStart',case when terms ? 'agreementType' then starts else null end,'leaseEnd',ends,'acknowledgedAt',acknowledged_at)) from public.bp_tenancies),'[]'),
 'payments',coalesce((select jsonb_agg(jsonb_build_object('id',id,'tenancyId',tenancy_id,'period',to_char(period,'YYYY-MM'),'method',method,'reference',reference,'bankReference',bank_reference,'notes',notes,'amountCents',amount,'paidOn',paid_on,'submittedAt',submitted_at,'state',state,'rejectionReason',reason,'reviewedAt',reviewed_at)) from public.bp_payments),'[]'),
 'notices',coalesce((select jsonb_agg(jsonb_build_object('id',id,'userId',user_id,'title',title,'message',message,'createdAt',created_at,'read',read)) from public.bp_notices),'[]')) into result;
 return result;
end $$;
revoke execute on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;

-- Commands run with narrowly checked ownership; no direct client INSERT/UPDATE.
create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u public.bp_profiles; p public.bp_properties; t public.bp_tenancies; pay public.bp_payments;
 rid uuid; result jsonb := 'null'; pr date; sd date; ed date; committed bigint; amt integer; confirm_it boolean;
 snapshot jsonb;
begin
 select * into u from public.bp_profiles where id=auth.uid();
 if not found then raise exception 'Sign in to continue.'; end if;
 -- Prevent concurrent mutations for the same caller; property/tenancy locks below
 -- additionally serialize related changes made by different users.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 if operation='profile' then
   update public.bp_profiles set name=trim(args->>'name'),phone=trim(args->>'phone') where id=u.id;
 elsif operation='property' then
   if u.role<>'landlord' then raise exception 'Landlord access required.'; end if;
   rid := nullif(args->>'id','')::uuid;
   if rid is null then
     insert into public.bp_properties(owner_id,name,address,suburb,city,postal_code,rooms,rent,due_day)
      values(u.id,trim(args->>'name'),trim(args->>'address'),args->>'suburb',args->>'city',args->>'postalCode',(args->>'rooms')::integer,(args->>'rentCents')::integer,(args->>'dueDay')::integer) returning id into rid;
   else
     select * into p from public.bp_properties where id=rid and owner_id=u.id for update;
     if not found then raise exception 'Property unavailable.'; end if;
     if exists(select 1 from public.bp_tenancies where property_id=rid and room>(args->>'rooms')::integer) then raise exception 'Room count cannot exclude existing tenancy records.'; end if;
     update public.bp_properties set name=trim(args->>'name'),address=trim(args->>'address'),suburb=args->>'suburb',city=args->>'city',postal_code=args->>'postalCode',rooms=(args->>'rooms')::integer,rent=(args->>'rentCents')::integer,due_day=(args->>'dueDay')::integer where id=rid;
   end if;
   result := to_jsonb(rid);
 elsif operation in ('deleteProperty','location') then
   select * into p from public.bp_properties where id=(args->>'id')::uuid and owner_id=u.id for update;
   if not found then raise exception 'Property unavailable.'; end if;
   if operation='deleteProperty' then
     if exists(select 1 from public.bp_tenancies where property_id=p.id) then raise exception 'A property with tenancy history cannot be deleted.'; end if;
     delete from public.bp_properties where id=p.id;
   else
     update public.bp_properties set latitude=(args->>'latitude')::double precision,longitude=(args->>'longitude')::double precision where id=p.id;
   end if;
 elsif operation='read' then
   update public.bp_notices set read=true where id=(args->>'id')::uuid and user_id=u.id;
   if not found then raise exception 'Notification unavailable.'; end if;
 elsif operation in ('payment','agreement','acknowledge','reminder','review') then
   if operation='review' then
     select * into pay from public.bp_payments where id=(args->>'id')::uuid;
     if not found then raise exception 'Payment unavailable.'; end if;
     rid := pay.tenancy_id;
   else rid := (args->>'tenancyId')::uuid; end if;
   select * into t from public.bp_tenancies where id=rid;
   if not found then raise exception 'Rental record unavailable.'; end if;
   -- All rental/room/payment mutations lock property first then tenancy, avoiding deadlocks.
   select * into p from public.bp_properties where id=t.property_id for update;
   select * into t from public.bp_tenancies where id=rid for update;
   if operation in ('payment','acknowledge') then
     if u.role<>'tenant' or t.tenant_id<>u.id then raise exception 'You may only change your own rental records.'; end if;
   elsif u.role<>'landlord' or p.owner_id<>u.id then raise exception 'You do not manage this property.'; end if;
   if operation='payment' then
     if coalesce(args->>'period','') !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Choose a valid rent month.'; end if;
     pr := ((args->>'period') || '-01')::date;
     if pr<date_trunc('month',t.starts)::date or pr>date_trunc('month',current_date)::date or (t.ends is not null and pr>date_trunc('month',t.ends)::date) then raise exception 'Choose a month within your tenancy through this month.'; end if;
     sd := (args->>'paidOn')::date;
     if sd>current_date or sd<'2020-01-01' then raise exception 'Choose a valid payment date, not a future date.'; end if;
     amt := (args->>'amountCents')::integer;
     select coalesce(sum(amount),0) into committed from public.bp_payments where tenancy_id=t.id and period=pr and state<>'rejected';
     if amt<=0 or committed+amt>t.rent then raise exception 'Amount exceeds rent available after confirmed and pending payments.'; end if;
     insert into public.bp_payments(tenancy_id,period,amount,method,reference,bank_reference,notes,paid_on)
       values(t.id,pr,amt,args->>'method',trim(args->>'reference'),trim(coalesce(args->>'bankReference','')),trim(coalesce(args->>'notes','')),sd) returning id into rid;
     insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Payment awaiting review',u.name || ' submitted R ' || (amt/100.0)::numeric(12,2) || ' for ' || to_char(pr,'YYYY-MM') || '.');
     result := to_jsonb(rid);
   elsif operation='review' then
     select * into pay from public.bp_payments where id=pay.id for update;
     if pay.state<>'pending' then raise exception 'This payment has already been reviewed.'; end if;
     confirm_it := (args->>'confirm')::boolean;
     if confirm_it is null then raise exception 'Choose confirm or reject.'; end if;
     if not confirm_it and length(trim(coalesce(args->>'reason',''))) not between 1 and 500 then raise exception 'Give a rejection reason of 1 to 500 characters.'; end if;
     select coalesce(sum(amount),0) into committed from public.bp_payments where tenancy_id=t.id and period=pay.period and state='confirmed';
     if confirm_it and committed+pay.amount>t.rent then raise exception 'Confirming would exceed the rent due.'; end if;
     update public.bp_payments set state=case when confirm_it then 'confirmed' else 'rejected' end,reason=case when confirm_it then null else trim(args->>'reason') end,reviewed_at=now() where id=pay.id;
     insert into public.bp_notices(user_id,title,message) values(t.tenant_id,case when confirm_it then 'Payment confirmed' else 'Payment rejected' end,'R ' || (pay.amount/100.0)::numeric(12,2) || ' for ' || to_char(pay.period,'YYYY-MM') || '. ' || case when confirm_it then 'Your receipt is available in payment history.' else trim(args->>'reason') end);
   elsif operation='reminder' then
     if coalesce(args->>'period','') !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' or length(trim(coalesce(args->>'message',''))) not between 1 and 500 then raise exception 'Enter a valid month and message.'; end if;
     insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Rent reminder • ' || (args->>'period'),trim(args->>'message'));
   elsif operation='acknowledge' then
     if not(t.terms ? 'agreementType') then raise exception 'No rental terms available to acknowledge.'; end if;
     update public.bp_tenancies set acknowledged_at=now() where id=t.id;
     insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Rental details reviewed',u.name || ' acknowledged reading their rental record. This is not a digital signature.');
   elsif operation='agreement' then
     sd := (args->>'start')::date; ed := nullif(args->>'end','')::date;
     if sd is null or sd<'2020-01-01' or sd>current_date or ed<sd then raise exception 'Check the rental dates.'; end if;
     if coalesce(args->>'agreementType','') not in ('Month-to-month','Fixed term') or (args->>'agreementType'='Fixed term' and ed is null) or (args->>'agreementType'='Month-to-month' and ed is not null) then raise exception 'Check the rental type and end date.'; end if;
     if coalesce((args->>'depositCents')::integer,-1)<0 or coalesce((args->>'depositReceivedCents')::integer,-1)<0 or (args->>'depositReceivedCents')::integer>(args->>'depositCents')::integer then raise exception 'Check the agreed and received deposit.'; end if;
     if length(trim(coalesce(args->>'utilities',''))) not between 1 and 1000 or length(trim(coalesce(args->>'houseRules',''))) not between 1 and 2000 then raise exception 'Record utility responsibilities and house rules.'; end if;
     if length(coalesce(args->>'emergencyName',''))>80 or (coalesce(args->>'emergencyPhone','')<>'' and args->>'emergencyPhone' !~ '^\+?[0-9 ()-]{7,20}$') then raise exception 'Check emergency contact details.'; end if;
     if exists(select 1 from public.bp_payments where tenancy_id=t.id and (period<date_trunc('month',sd)::date or period>date_trunc('month',ed)::date)) then raise exception 'Rental dates cannot exclude existing payment records.'; end if;
     if exists(select 1 from public.bp_tenancies x where x.property_id=t.property_id and x.room=t.room and x.id<>t.id and sd<=coalesce(x.ends,'infinity'::date) and x.starts<=coalesce(ed,'infinity'::date)) then raise exception 'These dates overlap another tenancy in this room.'; end if;
     update public.bp_tenancies set starts=sd,ends=ed,acknowledged_at=null,terms=jsonb_build_object('agreementType',args->>'agreementType','depositCents',(args->>'depositCents')::integer,'depositReceivedCents',(args->>'depositReceivedCents')::integer,'utilities',trim(args->>'utilities'),'houseRules',trim(args->>'houseRules'),'emergencyName',coalesce(args->>'emergencyName',''),'emergencyPhone',coalesce(args->>'emergencyPhone',''),'termsUpdatedAt',now()) where id=t.id;
     insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Rental details updated','Your landlord updated your rental record. Review the dates, deposit and responsibilities.');
   end if;
 else raise exception 'Unknown operation.';
 end if;
 -- SECURITY DEFINER commands cannot call the invoker snapshot with elevated reads.
 -- Return only the result; the client fetches its own RLS-filtered snapshot separately.
 return jsonb_build_object('result',result);
end $$;
revoke execute on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;
commit;


-- 202611060001_research_accounts.sql
-- RESEARCH UPDATE: additive upgrade. Apply after 202610240001_backyardpay.sql.
-- Keeps existing accounts, records and Auth configuration. No sample data.
begin;
alter table public.bp_tenancies alter column tenant_id drop not null;
alter table public.bp_tenancies add column if not exists record jsonb not null default '{}';
alter table public.bp_tenancies add column if not exists ended_on date;
alter table public.bp_tenancies add column if not exists invitation text not null default ('JOIN-'||upper(replace(gen_random_uuid()::text,'-','')));
create unique index if not exists bp_tenancy_invitation on public.bp_tenancies(invitation);
alter table public.bp_payments drop constraint if exists bp_payments_state_check;
alter table public.bp_payments add constraint bp_payments_state_check check(state in ('pending','confirmed','rejected','reversed'));
alter table public.bp_payments add column if not exists payer text not null default '';
alter table public.bp_payments add column if not exists entered_by uuid references public.bp_profiles(id);
alter table public.bp_payments add column if not exists receipt_details jsonb;
alter table public.bp_payments drop constraint if exists bp_payments_method_check;
alter table public.bp_payments add constraint bp_payments_method_check check(method in ('Cash','Cash deposit','EFT','PayShap','Debit order','Other'));
alter table public.bp_payments drop constraint if exists bp_payments_check;
alter table public.bp_payments drop constraint if exists bp_payment_bank_reference;
alter table public.bp_payments add constraint bp_payment_bank_reference check(method not in ('EFT','PayShap','Cash deposit','Debit order') or length(bank_reference)>0) not valid;
create table if not exists public.bp_rent_terms(
 tenancy_id uuid not null references public.bp_tenancies(id), period date not null check(extract(day from period)=1),
 amount integer not null check(amount>0), due_day integer not null check(due_day between 1 and 28),
 evidence text not null, created_at timestamptz not null default now(), actor uuid references public.bp_profiles(id),
 primary key(tenancy_id,period)
);
create table if not exists public.bp_allocations(
 payment_id uuid not null references public.bp_payments(id),period date not null check(extract(day from period)=1),
 amount integer not null check(amount>0),primary key(payment_id,period)
);
create table if not exists public.bp_case_records(
 id uuid primary key default gen_random_uuid(),tenancy_id uuid not null references public.bp_tenancies(id),
 kind text not null check(kind in ('deposit','inspection','repair','query','case_update','adjustment','audit')),
 body jsonb not null check(jsonb_typeof(body)='object' and octet_length(body::text)<=24000),
 actor uuid not null references public.bp_profiles(id),created_at timestamptz not null default now()
);
create index if not exists bp_cases_tenancy on public.bp_case_records(tenancy_id,created_at);
-- Only new tables are seeded with existing facts. These are not new payments.
insert into public.bp_rent_terms(tenancy_id,period,amount,due_day,evidence,actor)
 select t.id,date_trunc('month',t.starts)::date,t.rent,t.due_day,'Opening terms retained from existing rental record',p.owner_id
 from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id on conflict do nothing;
insert into public.bp_allocations(payment_id,period,amount)
 select id,period,amount from public.bp_payments where entered_by is null on conflict do nothing;
insert into public.bp_case_records(id,tenancy_id,kind,body,actor)
 select md5('opening-deposit:'||t.id::text)::uuid,t.id,'deposit',jsonb_build_object('event','opening','amountCents',(t.terms->>'depositReceivedCents')::integer,'reference','Opening deposit from previous record','date',current_date,'note','Migrated summary; not a new receipt of money'),p.owner_id
 from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id
 where coalesce((t.terms->>'depositReceivedCents')::integer,0)>0 on conflict do nothing;
alter table public.bp_rent_terms enable row level security;
alter table public.bp_allocations enable row level security;
alter table public.bp_case_records enable row level security;
revoke all on public.bp_rent_terms,public.bp_allocations,public.bp_case_records from anon,authenticated;
grant select on public.bp_rent_terms,public.bp_allocations,public.bp_case_records to authenticated;
drop policy if exists bp_terms_read on public.bp_rent_terms;
create policy bp_terms_read on public.bp_rent_terms for select to authenticated using(public.bp_sees_tenancy(tenancy_id));
drop policy if exists bp_allocations_read on public.bp_allocations;
create policy bp_allocations_read on public.bp_allocations for select to authenticated using(exists(select 1 from public.bp_payments p where p.id=payment_id and public.bp_sees_tenancy(p.tenancy_id)));
drop policy if exists bp_cases_read on public.bp_case_records;
create policy bp_cases_read on public.bp_case_records for select to authenticated using(public.bp_sees_tenancy(tenancy_id));

create or replace function public.bp_rent_due(tid uuid,pr date) returns integer language sql stable security definer set search_path=public,pg_temp as $$
 select case when pr<date_trunc('month',t.starts)::date or (t.ended_on is not null and pr>date_trunc('month',t.ended_on)::date) then 0 else
 coalesce((select amount from public.bp_rent_terms where tenancy_id=t.id and period<=pr order by period desc limit 1),t.rent)
 +coalesce((select sum((body->>'amountCents')::integer) from public.bp_case_records where tenancy_id=t.id and kind='adjustment' and body->>'period'=to_char(pr,'YYYY-MM')),0)::integer end
 from public.bp_tenancies t where t.id=tid;
$$;
revoke all on function public.bp_rent_due(uuid,date) from public,anon,authenticated;
create or replace function public.bp_capture_receipt(tid uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('tenant',coalesce(a.name,t.record->>'tenantName','Not recorded'),'landlord',o.name,'landlordAddress',t.record->>'landlordAddress','address',concat_ws(', ',p.address,nullif(p.suburb,''),nullif(p.city,''),nullif(p.postal_code,'')),'property',p.name,'room',t.room::text)
 from public.bp_tenancies t join public.bp_properties p on p.id=t.property_id join public.bp_profiles o on o.id=p.owner_id left join public.bp_profiles a on a.id=t.tenant_id where t.id=tid;
$$;
revoke all on function public.bp_capture_receipt(uuid) from public,anon,authenticated;

-- Save the previous checked command as an internal helper, never a public bypass.
do $$begin
 if to_regprocedure('public.bp_action_v1(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v1; end if;
 if to_regprocedure('public.bp_snapshot_v1()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v1; end if;
end $$;
revoke all on function public.bp_action_v1(text,jsonb) from public,anon,authenticated;
-- The legacy snapshot remains invoker/RLS filtered; it contains no privileged data.
revoke all on function public.bp_snapshot_v1() from public,anon;
grant execute on function public.bp_snapshot_v1() to authenticated;
create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v1();
 return s||jsonb_build_object('researchVersion',2,
 'tenancies',coalesce((select jsonb_agg(e||jsonb_build_object('record',t.record||jsonb_build_object('tenancyStartedOn',t.starts),'endedOn',t.ended_on,'ledgerVersion',2,'invitation',case when public.bp_owns(t.property_id) then t.invitation else null end)) from jsonb_array_elements(s->'tenancies') e join public.bp_tenancies t on t.id=(e->>'id')::uuid),'[]'),
 'payments',coalesce((select jsonb_agg(e||jsonb_build_object('payer',p.payer,'enteredBy',p.entered_by,'receiptDetails',p.receipt_details,'allocations',coalesce((select jsonb_agg(jsonb_build_object('period',to_char(a.period,'YYYY-MM'),'amountCents',a.amount)) from public.bp_allocations a where a.payment_id=p.id),'[]'))) from jsonb_array_elements(s->'payments') e join public.bp_payments p on p.id=(e->>'id')::uuid),'[]'),
 'rentTerms',coalesce((select jsonb_agg(jsonb_build_object('tenancyId',tenancy_id,'period',to_char(period,'YYYY-MM'),'amountCents',amount,'dueDay',due_day,'evidence',evidence,'createdAt',created_at)) from public.bp_rent_terms),'[]'),
 'caseRecords',coalesce((select jsonb_agg(jsonb_build_object('id',id,'tenancyId',tenancy_id,'kind',kind,'body',body,'actor',actor,'createdAt',created_at)) from public.bp_case_records),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u public.bp_profiles;p public.bp_properties;t public.bp_tenancies;pay public.bp_payments;
 rid uuid;pr date;sd date;ed date;amt integer;tot bigint;used bigint;bal bigint;part jsonb;record_body jsonb;owner boolean;ok boolean;result jsonb:='null';k text;ev text;parent public.bp_case_records;
begin
 select * into u from public.bp_profiles where id=auth.uid();if not found then raise exception 'Sign in to continue.';end if;
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,0));
 if operation in ('profile','property','deleteProperty','location','read','acknowledge') then return public.bp_action_v1(operation,args);end if;
 if operation='join_rental' then
  if u.role<>'tenant' then raise exception 'Tenant account required.';end if;
  if exists(select 1 from public.bp_tenancies where tenant_id=u.id and ended_on is null) then raise exception 'Complete the existing rental handover before joining another.';end if;
  select * into t from public.bp_tenancies where invitation=upper(trim(args->>'invitation')) and tenant_id is null and ended_on is null;
  if not found then raise exception 'Private rental invitation unavailable.';end if;
  perform 1 from public.bp_properties where id=t.property_id for update;
  select * into t from public.bp_tenancies where id=t.id for update;
  if t.tenant_id is not null or t.ended_on is not null then raise exception 'Invitation already used or rental ended.';end if;
  update public.bp_tenancies set tenant_id=u.id,invitation='USED-'||gen_random_uuid()::text where id=t.id;
  return jsonb_build_object('result',t.id);
 end if;
 if operation='tenancy' then
  select * into p from public.bp_properties where id=(args->>'propertyId')::uuid and owner_id=u.id for update;
  if not found or u.role<>'landlord' then raise exception 'Property unavailable.';end if;
  amt:=(args->>'room')::integer;sd:=(args->>'start')::date;
  if amt<1 or amt>p.rooms or sd<'2020-01-01' or sd>current_date or length(trim(coalesce(args->>'name',''))) not between 2 and 80 then raise exception 'Check tenant, room and start date.';end if;
  if exists(select 1 from public.bp_tenancies where property_id=p.id and room=amt and (ended_on is null or ended_on>=sd)) then raise exception 'Room has an overlapping tenancy. Complete handover first.';end if;
  insert into public.bp_tenancies(property_id,tenant_id,room,starts,rent,due_day,record) values(p.id,null,amt,sd,p.rent,p.due_day,jsonb_build_object('tenantName',trim(args->>'name'),'tenantPhone',left(coalesce(args->>'phone',''),30),'tenantEmail',left(coalesce(args->>'email',''),254))) returning * into t;
  insert into public.bp_rent_terms values(t.id,date_trunc('month',sd)::date,p.rent,p.due_day,'Opening agreed rental rate',now(),u.id);
  return jsonb_build_object('result',t.id);
 end if;
 if operation in ('review','allocate_credit','reverse_payment') then
  select * into pay from public.bp_payments where id=(args->>'id')::uuid;if not found then raise exception 'Payment unavailable.';end if;rid:=pay.tenancy_id;
 else rid:=(args->>'tenancyId')::uuid;end if;
 select * into t from public.bp_tenancies where id=rid;if not found then raise exception 'Rental record unavailable.';end if;
 select * into p from public.bp_properties where id=t.property_id for update;
 select * into t from public.bp_tenancies where id=rid for update;
 owner:=p.owner_id=u.id and u.role='landlord';
 if not owner and (t.tenant_id is null or t.tenant_id<>u.id) then raise exception 'You do not have access to this rental record.';end if;
 if operation='reverse_payment' then
  if not owner or pay.state<>'confirmed' or length(trim(coalesce(args->>'reason',''))) not between 3 and 1500 then raise exception 'Only the landlord can reverse a confirmed receipt. Record the actual return/reversal and its evidence.';end if;
  update public.bp_payments set state='reversed',reason=trim(args->>'reason') where id=pay.id;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','payment_reversal','paymentId',pay.id,'reference',pay.reference,'note',args->>'reason','date',current_date),u.id);
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Received payment reversed','Check the retained receipt record, reversal explanation and updated rental account.');end if;
  return jsonb_build_object('result',pay.id);
 end if;
 if operation in ('payment','review','allocate_credit') then
  if operation='payment' then
   amt:=(args->>'amountCents')::integer;sd:=(args->>'paidOn')::date;
   if amt is null or amt<=0 or sd is null or sd<'2020-01-01' or sd>current_date or length(trim(coalesce(args->>'payer',''))) not between 2 and 100 then raise exception 'Check amount, actual payer and payment date.';end if;
   if owner and coalesce((args->>'received')::boolean,false) is not true then raise exception 'Check money received before issuing a receipt.';end if;
   insert into public.bp_payments(tenancy_id,period,amount,method,reference,bank_reference,notes,paid_on,state,reviewed_at,payer,entered_by,receipt_details)
    values(t.id,date_trunc('month',sd)::date,amt,args->>'method',trim(args->>'reference'),trim(coalesce(args->>'bankReference','')),trim(coalesce(args->>'notes','')),sd,case when owner then 'confirmed' else 'pending' end,case when owner then now() else null end,trim(args->>'payer'),u.id,case when owner then public.bp_capture_receipt(t.id) else null end) returning * into pay;
   ok:=owner;
  else
   if not owner then raise exception 'Only the linked landlord can confirm or allocate payments.';end if;
   select * into pay from public.bp_payments where id=pay.id for update;
   if operation='review' then
    if pay.state<>'pending' then raise exception 'This payment has already been reviewed.';end if;
    ok:=(args->>'confirm')::boolean;if ok is null then raise exception 'Choose confirm or reject.';end if;
    if not ok then
     if length(trim(coalesce(args->>'reason',''))) not between 1 and 500 then raise exception 'Give a reason for the rejected record.';end if;
     update public.bp_payments set state='rejected',reason=trim(args->>'reason'),reviewed_at=now() where id=pay.id;
     if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Payment record rejected',trim(args->>'reason')||' This is a record decision, not a legal finding.');end if;
     return jsonb_build_object('result',null);
    end if;
    delete from public.bp_allocations where payment_id=pay.id;
   else
    if pay.state<>'confirmed' then raise exception 'Only confirmed unallocated credit can be allocated.';end if;ok:=true;
   end if;
  end if;
  if coalesce(jsonb_typeof(args->'allocations'),'')<>'array' or coalesce(jsonb_array_length(args->'allocations'),100)>120 then raise exception 'Provide a valid allocation list.';end if;
  select coalesce(sum(amount),0) into tot from public.bp_allocations where payment_id=pay.id;
  for part in select value from jsonb_array_elements(args->'allocations') loop
   if coalesce(part->>'period','') !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Use a valid rental month.';end if;
   pr:=((part->>'period')||'-01')::date;amt:=(part->>'amountCents')::integer;
   if amt is null or amt<=0 or pr<date_trunc('month',t.starts)::date or pr>date_trunc('month',current_date)::date or public.bp_rent_due(t.id,pr)<=0 then raise exception 'Choose a charged rental month and positive allocation.';end if;
   tot:=tot+amt;if tot>pay.amount then raise exception 'Allocations exceed the money received.';end if;
   if ok then
    select coalesce(sum(a.amount),0) into used from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id where x.tenancy_id=t.id and x.state='confirmed' and a.period=pr;
    if used+amt>public.bp_rent_due(t.id,pr) then raise exception 'Allocation exceeds this month’s recorded charge. Leave the remainder as credit.';end if;
   end if;
   if operation='allocate_credit' then
    insert into public.bp_allocations values(pay.id,pr,amt) on conflict(payment_id,period) do update set amount=public.bp_allocations.amount+excluded.amount;
   else insert into public.bp_allocations values(pay.id,pr,amt);end if;
  end loop;
  if ok and operation<>'allocate_credit' then
   update public.bp_payments set state='confirmed',reviewed_at=now(),receipt_details=public.bp_capture_receipt(t.id)||jsonb_build_object('issuedAllocations',coalesce((select jsonb_agg(jsonb_build_object('period',to_char(period,'YYYY-MM'),'amountCents',amount)) from public.bp_allocations where payment_id=pay.id),'[]'),'issuedCreditCents',pay.amount-tot) where id=pay.id;
  end if;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action',operation,'paymentId',pay.id,'reference',pay.reference,'note',coalesce(args->>'reason','Recorded payment/allocation')),u.id);
  if owner and t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Payment confirmed','Money received and recorded. View its allocations, credit and rental receipt.');
  elsif not owner then insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Payment awaiting reconciliation','A tenant reported a payment. Review the money received and its proposed allocations.');end if;
  result:=to_jsonb(pay.id);
 elsif operation='reminder' then
  if not owner or t.tenant_id is null then raise exception 'Only linked tenant accounts can receive in-app reminders. Share their statement separately.';end if;
  return public.bp_action_v1(operation,args);
 elsif operation='agreement' then
  if not owner then raise exception 'Only the landlord can update agreed terms.';end if;
  sd:=(args->>'start')::date;ed:=nullif(args->>'end','')::date;
  if sd is null or sd<'2020-01-01' or sd>current_date or ed<sd then raise exception 'Check rental dates.';end if;
  if coalesce(args->>'agreementType','') not in ('Month-to-month','Fixed term') or (args->>'agreementType'='Fixed term' and ed is null) or (args->>'agreementType'='Month-to-month' and ed is not null) then raise exception 'Check the rental type and planned end date.';end if;
  if (args->>'depositCents')::integer<0 or length(trim(args->>'utilities')) not between 1 and 1000 or length(trim(args->>'houseRules')) not between 1 and 2000 then raise exception 'Check the deposit, utilities and house rules.';end if;
  if exists(select 1 from public.bp_payments where tenancy_id=t.id) and sd<>t.starts then raise exception 'Start date is locked once payment history exists. Record a documented account adjustment instead.';end if;
  record_body:=coalesce(args->'details','{}');
  foreach k in array array['landlordAddress','tenantAddress','authority','dwellingDescription','sharedFacilities','paymentInstructions','noticeTerms','escalationTerms','otherCharges'] loop
   if length(trim(coalesce(record_body->>k,''))) not between 1 and 1500 then raise exception 'Complete all essential lease details; write None where genuinely not applicable.';end if;
  end loop;
  if exists(select 1 from public.bp_tenancies x where x.property_id=t.property_id and x.room=t.room and x.id<>t.id and sd<=coalesce(x.ended_on,'infinity'::date) and x.starts<=coalesce(t.ended_on,'infinity'::date)) then raise exception 'Rental dates overlap another room occupant.';end if;
  update public.bp_tenancies set starts=sd,ends=ed,acknowledged_at=null,record=record||record_body,terms=jsonb_build_object('agreementType',args->>'agreementType','depositCents',(args->>'depositCents')::integer,'depositReceivedCents',coalesce((terms->>'depositReceivedCents')::integer,0),'utilities',trim(args->>'utilities'),'houseRules',trim(args->>'houseRules'),'emergencyName',left(coalesce(args->>'emergencyName',''),80),'emergencyPhone',left(coalesce(args->>'emergencyPhone',''),20),'termsUpdatedAt',now()) where id=t.id;
  if sd<>t.starts then update public.bp_rent_terms set period=date_trunc('month',sd)::date where tenancy_id=t.id and period=date_trunc('month',t.starts)::date;end if;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','agreement','previous',t.record||t.terms,'updated',record_body||args),u.id);
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Rental details updated','Review the changed terms. Reading acknowledgement is not a signature.');end if;
 elsif operation='rent_term' then
  if not owner then raise exception 'Only the landlord can record an agreed rent change.';end if;
  pr:=((args->>'period')||'-01')::date;
  if pr<=date_trunc('month',current_date)::date or length(trim(coalesce(args->>'evidence',''))) not between 3 and 1500 then raise exception 'Use a future month and record the actual agreement/evidence.';end if;
  insert into public.bp_rent_terms values(t.id,pr,(args->>'amountCents')::integer,(args->>'dueDay')::integer,trim(args->>'evidence'),now(),u.id);
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Dated rent change recorded','Check the effective month and agreement in rental account history.');end if;
 elsif operation='close_tenancy' then
  sd:=(args->>'date')::date;
  if not owner or sd is null or sd<t.starts or sd>current_date or length(trim(coalesce(args->>'note',''))) not between 3 and 1500 then raise exception 'Record the actual handover date and agreed final-billing explanation.';end if;
  if t.ended_on is not null then raise exception 'Handover is already recorded.';end if;
  if exists(select 1 from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id where x.tenancy_id=t.id and a.period>date_trunc('month',sd)::date) then raise exception 'Later allocations exist. Reconcile the account before handover.';end if;
  update public.bp_tenancies set ended_on=sd where id=t.id;
  insert into public.bp_case_records(tenancy_id,kind,body,actor) values(t.id,'audit',jsonb_build_object('action','handover','date',sd,'note',args->>'note'),u.id);
 elsif operation='case' then
  k:=args->>'kind';record_body:=args->'body';
  if args->>'eventId' is null then raise exception 'A stable record identifier is required.';end if;
  select * into parent from public.bp_case_records where id=(args->>'eventId')::uuid;
  if found then
   if parent.tenancy_id=t.id and parent.actor=u.id and parent.kind=k and (parent.body-'receiptDetails'-'status')=(record_body-'receiptDetails'-'status') then return jsonb_build_object('result',parent.id);end if;
   raise exception 'This record identifier is already saved. Refresh before creating another record.';
  end if;
  if k not in ('deposit','inspection','repair','query','case_update','adjustment') or jsonb_typeof(record_body)<>'object' or octet_length(record_body::text)>16000 then raise exception 'Check the rental record fields.';end if;
  if k in ('deposit','inspection','adjustment') and not owner then raise exception 'Only the landlord can enter this record.';end if;
  if k='deposit' then
   ev:=record_body->>'event';amt:=(record_body->>'amountCents')::integer;sd:=(record_body->>'date')::date;
   if coalesce(ev,'') not in ('received','interest','deduction','refund') or amt is null or amt<=0 or sd is null or sd<'2020-01-01' or sd>current_date or length(trim(coalesce(record_body->>'reference',''))) not between 3 and 500 then raise exception 'Check deposit event, amount, date and evidence/reference.';end if;
   select coalesce(sum(case when c.body->>'event' in ('deduction','refund') then -(c.body->>'amountCents')::integer else (c.body->>'amountCents')::integer end),0) into bal from public.bp_case_records c where c.tenancy_id=t.id and c.kind='deposit';
   if ev in ('deduction','refund') and amt>bal then raise exception 'This exceeds the deposit and interest held.';end if;
   if ev='deduction' and (length(trim(coalesce(record_body->>'note','')))<3 or not exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='inspection' and c.body->>'stage'='Entry') or not exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='inspection' and c.body->>'stage'='Exit')) then raise exception 'Record entry/exit inspections and cost evidence before a proposed deduction. Verify the legal conditions separately.';end if;
   record_body:=record_body||jsonb_build_object('receiptDetails',public.bp_capture_receipt(t.id));
  elsif k='inspection' then
   sd:=(record_body->>'date')::date;
   if coalesce(record_body->>'stage','') not in ('Entry','Exit') or sd is null or sd<t.starts-31 or sd>current_date or length(trim(coalesce(record_body->>'condition',''))) not between 3 and 5000 or length(trim(coalesce(record_body->>'participants',''))) not between 3 and 500 then raise exception 'Record stage, actual date, participants and defects/condition.';end if;
  elsif k='adjustment' then
   amt:=(record_body->>'amountCents')::integer;pr:=((record_body->>'period')||'-01')::date;
   if amt is null or amt=0 or length(trim(coalesce(record_body->>'reason',''))) not between 3 and 1500 or pr<date_trunc('month',t.starts)::date or pr>date_trunc('month',current_date)::date or (t.ended_on is not null and pr>date_trunc('month',t.ended_on)::date) then raise exception 'Use a charged month, nonzero adjustment and documented reason/evidence.';end if;
   select coalesce(sum(a.amount),0) into used from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id where x.tenancy_id=t.id and x.state='confirmed' and a.period=pr;
   if public.bp_rent_due(t.id,pr)+amt<used then raise exception 'Adjustment would reduce the charge below confirmed allocations. Reconcile received funds first.';end if;
  elsif k='case_update' then
   select * into parent from public.bp_case_records where id=(record_body->>'parentId')::uuid and tenancy_id=t.id and kind in ('repair','query');
   if not found or length(trim(coalesce(record_body->>'message',''))) not between 3 and 3000 or (not owner and coalesce(record_body->>'status','')<>'comment') or (owner and record_body->>'status' not in ('open','in_progress','resolved','comment')) then raise exception 'Only the landlord may change case status; both parties can add a message.';end if;
  else
   if length(trim(coalesce(record_body->>'description',''))) not between 3 and 3000 then raise exception 'Describe the repair or account query.';end if;
   record_body:=record_body||jsonb_build_object('status','open');
  end if;
  insert into public.bp_case_records(id,tenancy_id,kind,body,actor) values((args->>'eventId')::uuid,t.id,k,record_body,u.id) returning id into rid;result:=to_jsonb(rid);
  if owner and t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Rental record updated','A '||k||' record was added to your tenancy. Review the details.');
  elsif not owner then insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Rental record update','Your tenant added a repair/account query message.');end if;
 else raise exception 'Unknown operation.';end if;
 return jsonb_build_object('result',result);
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

-- Existing occupants can claim only the private invitation generated for that
-- tenancy; knowing a property code and occupied room is not sufficient.
create or replace function public.bp_on_signup() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare m jsonb:=new.raw_user_meta_data;p public.bp_properties;t public.bp_tenancies;r integer;join_code text:=upper(trim(m->>'code'));
begin
 if coalesce(m->>'role','') not in ('landlord','tenant') then raise exception 'Choose a valid role.';end if;
 insert into public.bp_profiles values(new.id,m->>'role',trim(m->>'name'),new.email,trim(m->>'phone'));
 if m->>'role'='tenant' then
  select * into t from public.bp_tenancies where invitation=join_code;
  if found then
   select * into p from public.bp_properties where id=t.property_id for update;
   select * into t from public.bp_tenancies where id=t.id for update;
   if t.tenant_id is not null or t.ended_on is not null or trim(m->>'room')<>t.room::text then raise exception 'Invitation unavailable or room does not match.';end if;
   update public.bp_tenancies set tenant_id=new.id,invitation='USED-'||gen_random_uuid()::text where id=t.id;
  else
   select * into p from public.bp_properties where public.bp_properties.code=join_code for update;
   if not found or coalesce(m->>'room','') !~ '^[1-9][0-9]{0,2}$' then raise exception 'Ask your landlord for a valid code and room.';end if;
   r:=(m->>'room')::integer;
   if r>p.rooms or exists(select 1 from public.bp_tenancies where property_id=p.id and room=r and (ended_on is null or ended_on>=current_date)) then raise exception 'Room unavailable. For an existing rental ask for its private invitation.';end if;
   insert into public.bp_tenancies(property_id,tenant_id,room,starts,rent,due_day) values(p.id,new.id,r,current_date,p.rent,p.due_day) returning * into t;
   insert into public.bp_rent_terms values(t.id,date_trunc('month',current_date)::date,p.rent,p.due_day,'Opening rental terms',now(),p.owner_id);
  end if;
  insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Tenant account connected',trim(m->>'name')||' is linked to room '||t.room||'.');
 end if;
 return new;
end $$;
revoke all on function public.bp_on_signup() from public,anon,authenticated;
commit;


-- 202611060002_private_documents.sql
begin;
-- Private supporting files. Uploaded evidence is not bank verification or a signature.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('bp-documents','bp-documents',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
create table if not exists public.bp_documents(
 id uuid primary key default gen_random_uuid(),tenancy_id uuid not null references public.bp_tenancies(id),
 object_path text not null unique,title text not null check(length(title) between 3 and 150),
 category text not null check(category in ('Lease','Inspection','Payment evidence','Deposit evidence','Other')),
 uploaded_by uuid not null references public.bp_profiles(id),created_at timestamptz not null default now()
);
alter table public.bp_documents enable row level security;
revoke all on public.bp_documents from anon,authenticated;
grant select on public.bp_documents to authenticated;
drop policy if exists document_scope on public.bp_documents;
create policy document_scope on public.bp_documents for select to authenticated using(public.bp_sees_tenancy(tenancy_id));
drop policy if exists bp_file_read on storage.objects;
create policy bp_file_read on storage.objects for select to authenticated using(bucket_id='bp-documents' and exists(select 1 from public.bp_documents d where d.object_path=name and public.bp_sees_tenancy(d.tenancy_id)));
drop policy if exists bp_file_upload on storage.objects;
create policy bp_file_upload on storage.objects for insert to authenticated with check(bucket_id='bp-documents' and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' and public.bp_sees_tenancy(split_part(name,'/',1)::uuid));
-- Only orphaned files owned by their uploader can be cleaned up. Registered evidence cannot be overwritten/deleted by the app.
drop policy if exists bp_file_cleanup on storage.objects;
create policy bp_file_cleanup on storage.objects for delete to authenticated using(bucket_id='bp-documents' and owner_id=auth.uid()::text and not exists(select 1 from public.bp_documents d where d.object_path=name));
create or replace function public.bp_register_document(tid uuid,path text,label text,category_name text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare rid uuid;
begin
 if not public.bp_sees_tenancy(tid) then raise exception 'Rental access required.';end if;
 if split_part(path,'/',1)<>tid::text or path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' or not exists(select 1 from storage.objects o where o.bucket_id='bp-documents' and o.name=path and o.owner_id=auth.uid()::text) then raise exception 'Upload your file to this rental first.';end if;
 insert into public.bp_documents(tenancy_id,object_path,title,category,uploaded_by) values(tid,path,trim(label),category_name,auth.uid()) returning id into rid;
 return rid;
end $$;
revoke all on function public.bp_register_document(uuid,text,text,text) from public,anon;
grant execute on function public.bp_register_document(uuid,text,text,text) to authenticated;

commit;


-- 202611070001_first_month_proration.sql
-- Additive update: new rental agreements only. Never recalculate existing balances.
begin;
alter table public.bp_properties add column if not exists prorate_first boolean not null default true;
alter table public.bp_tenancies add column if not exists first_month_prorated boolean not null default false;

create or replace function public.bp_first_month_policy() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if tg_op='INSERT' then
  select prorate_first into new.first_month_prorated from public.bp_properties where id=new.property_id;
 elsif new.first_month_prorated is distinct from old.first_month_prorated then
  raise exception 'The recorded first-month billing basis cannot be rewritten. Use an evidenced charge adjustment.';
 end if;
 return new;
end $$;
revoke all on function public.bp_first_month_policy() from public,anon,authenticated;
drop trigger if exists bp_first_month_policy on public.bp_tenancies;
create trigger bp_first_month_policy before insert or update on public.bp_tenancies for each row execute function public.bp_first_month_policy();

create or replace function public.bp_rent_due(tid uuid,pr date) returns integer language sql stable security definer set search_path=public,pg_temp as $$
 select case when pr<date_trunc('month',t.starts)::date or (t.ended_on is not null and pr>date_trunc('month',t.ended_on)::date) then 0 else
 (case when t.first_month_prorated and pr=date_trunc('month',t.starts)::date then
 round(coalesce((select amount from public.bp_rent_terms where tenancy_id=t.id and period<=pr order by period desc limit 1),t.rent)::numeric
 * (((date_trunc('month',t.starts)+interval '1 month')::date-t.starts)::integer)
 / extract(day from (date_trunc('month',t.starts)+interval '1 month - 1 day')))::integer
 else coalesce((select amount from public.bp_rent_terms where tenancy_id=t.id and period<=pr order by period desc limit 1),t.rent) end)
 +coalesce((select sum((body->>'amountCents')::integer) from public.bp_case_records where tenancy_id=t.id and kind='adjustment' and body->>'period'=to_char(pr,'YYYY-MM')),0)::integer end
 from public.bp_tenancies t where t.id=tid;
$$;
revoke all on function public.bp_rent_due(uuid,date) from public,anon,authenticated;

do $$begin
 if to_regprocedure('public.bp_action_v2(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v2;end if;
 if to_regprocedure('public.bp_snapshot_v2()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v2;end if;
end $$;
revoke all on function public.bp_action_v2(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v2() from public,anon;
grant execute on function public.bp_snapshot_v2() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r jsonb;
begin
 r:=public.bp_action_v2(operation,args);
 if operation='property' and args ? 'prorateFirstMonth' then
  if jsonb_typeof(args->'prorateFirstMonth')<>'boolean' then raise exception 'Choose the first-month billing basis.';end if;
  update public.bp_properties set prorate_first=(args->>'prorateFirstMonth')::boolean where id=(r->>'result')::uuid and owner_id=auth.uid();
 end if;
 return r;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v2();
 return s||jsonb_build_object('prorationVersion',1,
 'properties',coalesce((select jsonb_agg(e||jsonb_build_object('prorateFirstMonth',p.prorate_first)) from jsonb_array_elements(s->'properties') e join public.bp_properties p on p.id=(e->>'id')::uuid),'[]'),
 'tenancies',coalesce((select jsonb_agg(e||jsonb_build_object('record',e->'record'||jsonb_build_object('firstMonthProration',case when t.first_month_prorated then 'actual_days' else 'full_month' end,'tenancyStartedOn',t.starts))) from jsonb_array_elements(s->'tenancies') e join public.bp_tenancies t on t.id=(e->>'id')::uuid),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;


-- 202611070002_deposits_and_reports.sql
-- Apply after the Research and Proration updates. No existing financial history is rewritten.
begin;
alter table public.bp_properties add column if not exists security_deposit integer check(security_deposit>=0);
alter table public.bp_documents add column if not exists case_id uuid references public.bp_case_records(id);

create or replace function public.bp_security_deposit_policy() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare amount integer;
begin
 select security_deposit into amount from public.bp_properties where id=new.property_id;
 if amount is null then raise exception 'Ask the landlord to specify the property security deposit first (0 if none).';end if;
 new.terms:=coalesce(new.terms,'{}')||jsonb_build_object('depositCents',amount,'depositReceivedCents',0);
 new.record:=coalesce(new.record,'{}')||jsonb_build_object('depositDueOn',new.starts,'depositBasis','Property deposit agreed at onboarding');
 return new;
end $$;
revoke all on function public.bp_security_deposit_policy() from public,anon,authenticated;
drop trigger if exists bp_security_deposit_policy on public.bp_tenancies;
create trigger bp_security_deposit_policy before insert on public.bp_tenancies for each row execute function public.bp_security_deposit_policy();

do $$begin
 if to_regprocedure('public.bp_action_v3(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v3;end if;
 if to_regprocedure('public.bp_snapshot_v3()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v3;end if;
end $$;
revoke all on function public.bp_action_v3(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v3() from public,anon;
grant execute on function public.bp_snapshot_v3() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r jsonb;b jsonb;d date;tid uuid;
begin
 if operation='property' and args ? 'securityDepositCents' then
  if coalesce(jsonb_typeof(args->'securityDepositCents'),'')<>'number' or (args->>'securityDepositCents')::integer<0 then raise exception 'Specify a non-negative security deposit, or 0 if none.';end if;
 end if;
 if operation='case' and args->>'kind' in ('repair','query') then
  b:=args->'body';d:=(b->>'incidentDate')::date;
  if coalesce(b->>'category','') not in ('Water / plumbing','Gate / shared facilities','Electrical / safety','Structure / damp','Noise / nuisance','Damage inside my room','Account / deposit query','Other')
  or coalesce(b->>'urgency','') not in ('Routine','Urgent','Immediate danger')
  or coalesce(b->>'cause','') not in ('Unknown','Wear / deterioration suspected','I or my household caused it','Third party suspected','Other')
  or length(trim(coalesce(b->>'location',''))) not between 3 and 250
  or length(coalesce(b->>'accessAvailability',''))>500 or d is null or d<'2020-01-01' or d>current_date then raise exception 'Record category, urgency, date, location and what you know about the cause.';end if;
  -- Ignore attempts to turn a factual report into a financial decision.
  if b ?| array['liability','deductionCents','chargeCents','bankVerified'] then raise exception 'A report does not assign liability or deduct money.';end if;
 end if;
 r:=public.bp_action_v3(operation,args);
 if operation='property' and args ? 'securityDepositCents' then
  update public.bp_properties set security_deposit=(args->>'securityDepositCents')::integer where id=(r->>'result')::uuid and owner_id=auth.uid();
 end if;
 return r;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v3();
 return s||jsonb_build_object('depositReportsVersion',1,'properties',coalesce((select jsonb_agg(e||jsonb_build_object('securityDepositCents',p.security_deposit)) from jsonb_array_elements(s->'properties') e join public.bp_properties p on p.id=(e->>'id')::uuid),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;

create or replace function public.bp_register_case_document(tid uuid,path text,label text,category_name text,report_id uuid) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare rid uuid;
begin
 if not public.bp_sees_tenancy(tid) or not exists(select 1 from public.bp_case_records where id=report_id and tenancy_id=tid and kind in ('repair','query')) then raise exception 'Report unavailable for this rental.';end if;
 rid:=public.bp_register_document(tid,path,label,category_name);
 update public.bp_documents set case_id=report_id where id=rid;
 return rid;
end $$;
revoke all on function public.bp_register_case_document(uuid,text,text,text,uuid) from public,anon;
grant execute on function public.bp_register_case_document(uuid,text,text,text,uuid) to authenticated;
commit;


-- 202611070003_invitation_only_signup.sql
-- Tenants claim only the landlord-created rental; public property codes never assign rooms.
begin;
create or replace function public.bp_tenant_signup_mode() returns text language sql immutable set search_path=public,pg_temp as $$select 'invitation_only'::text$$;
revoke all on function public.bp_tenant_signup_mode() from public;
grant execute on function public.bp_tenant_signup_mode() to anon,authenticated;

create or replace function public.bp_on_signup() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare m jsonb:=new.raw_user_meta_data;p public.bp_properties;t public.bp_tenancies;join_code text:=upper(trim(m->>'code'));
begin
 if coalesce(m->>'role','') not in ('landlord','tenant') then raise exception 'Choose a valid role.';end if;
 if m->>'role'='tenant' then
  if coalesce(join_code,'') !~ '^JOIN-[A-F0-9]{32}$' or length(trim(coalesce(m->>'room','')))>0 then
   raise exception 'The landlord assigns the room. Use a private tenant invitation only, without a room choice.';
  end if;
  select * into t from public.bp_tenancies where invitation=join_code;
  if not found then raise exception 'Private invitation unavailable. Ask your landlord to check it.';end if;
  select * into p from public.bp_properties where id=t.property_id for update;
  select * into t from public.bp_tenancies where id=t.id for update;
  if not found or t.invitation<>join_code or t.tenant_id is not null or t.ended_on is not null then raise exception 'Private invitation unavailable. Ask your landlord to check it.';end if;
 end if;
 insert into public.bp_profiles values(new.id,m->>'role',trim(m->>'name'),new.email,trim(m->>'phone'));
 if m->>'role'='tenant' then
  -- Preserve the exact room, actual move-in date, rent, deposit, allocations and history.
  update public.bp_tenancies set tenant_id=new.id,invitation='USED-'||gen_random_uuid()::text where id=t.id;
  insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Tenant account connected',trim(m->>'name')||' joined the rental you assigned in room '||t.room||'.');
 end if;
 return new;
end $$;
revoke all on function public.bp_on_signup() from public,anon,authenticated;
commit;


-- 202611080001_simple_rentals.sql
-- Room-specific new-tenant rates and compact rental workflows. Existing history is retained.
begin;
alter table public.bp_properties add column if not exists room_rents jsonb not null default '{}' check(jsonb_typeof(room_rents)='object');
alter table public.bp_notices add column if not exists request_id uuid;
create unique index if not exists bp_notice_request on public.bp_notices(user_id,request_id) where request_id is not null;
create or replace function public.bp_room_rate() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 select coalesce((room_rents->>new.room::text)::integer,rent) into new.rent from public.bp_properties where id=new.property_id;
 return new;
end $$;
revoke all on function public.bp_room_rate() from public,anon,authenticated;
drop trigger if exists bp_room_rate on public.bp_tenancies;
create trigger bp_room_rate before insert on public.bp_tenancies for each row execute function public.bp_room_rate();
do $$begin
 if to_regprocedure('public.bp_action_v4(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v4;end if;
 if to_regprocedure('public.bp_snapshot_v4()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v4;end if;
end $$;
revoke all on function public.bp_action_v4(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v4() from public,anon;
grant execute on function public.bp_snapshot_v4() to authenticated;
create or replace function public.bp_action(operation text,args jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare p public.bp_properties;t public.bp_tenancies;r jsonb;entry record;amount integer;held bigint;ev text;eid uuid;existing public.bp_case_records;b jsonb;recipient uuid;sent integer:=0;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation in ('room_rents','property_message','deposit_update') then
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
  if not exists(select 1 from public.bp_profiles where id=auth.uid() and role='landlord') then raise exception 'Landlord access required.';end if;
 end if;
 if operation='room_rents' then
  select * into p from public.bp_properties where id=(args->>'propertyId')::uuid and owner_id=auth.uid() for update;
  if not found then raise exception 'Property unavailable.';end if;
  if coalesce(jsonb_typeof(args->'rates'),'')<>'object' then raise exception 'Check room rents.';end if;
  for entry in select * from jsonb_each(args->'rates') loop
   if entry.key !~ '^[1-9][0-9]{0,2}$' or entry.key::integer>p.rooms or jsonb_typeof(entry.value)<>'number' or entry.value::text !~ '^[1-9][0-9]*$' or (entry.value::text)::bigint>2147483647 then raise exception 'Use an existing room and a positive rent amount.';end if;
  end loop;
  update public.bp_properties set room_rents=args->'rates' where id=p.id;
  return jsonb_build_object('result',p.id);
 elsif operation='property_message' then
  select * into p from public.bp_properties where id=(args->>'propertyId')::uuid and owner_id=auth.uid() for update;
  if not found or length(trim(coalesce(args->>'message',''))) not between 3 and 1500 then raise exception 'Choose your property and write a message.';end if;
  if args->>'tenancyId' is not null and not exists(select 1 from public.bp_tenancies where id=(args->>'tenancyId')::uuid and property_id=p.id and tenant_id is not null) then raise exception 'Linked tenant unavailable.';end if;
  -- A stable request id prevents double notification on a retried broadcast.
  eid:=(args->>'eventId')::uuid;if eid is null then raise exception 'Message identifier required.';end if;
  for recipient in select distinct tenant_id from public.bp_tenancies where property_id=p.id and tenant_id is not null and (case when args->>'tenancyId' is null then ended_on is null else id=(args->>'tenancyId')::uuid end) loop
   if not exists(select 1 from public.bp_notices where user_id=recipient and request_id=eid) then
    insert into public.bp_notices(user_id,title,message,request_id) values(recipient,'Property update: '||p.name,trim(args->>'message'),eid);sent:=sent+1;
   end if;
  end loop;
  return jsonb_build_object('result',sent);
 elsif operation='deposit_update' then
  select * into t from public.bp_tenancies where id=(args->>'tenancyId')::uuid;
  select * into p from public.bp_properties where id=t.property_id and owner_id=auth.uid() for update;
  if not found then raise exception 'Rental unavailable.';end if;
  select * into t from public.bp_tenancies where id=t.id for update;
  eid:=(args->>'eventId')::uuid;b:=args->'body';ev:=b->>'event';amount:=(b->>'amountCents')::integer;
  select * into existing from public.bp_case_records where id=eid;
  if found then
   if existing.tenancy_id=t.id and existing.actor=auth.uid() and existing.kind='deposit' and existing.body-'receiptDetails'=b then return jsonb_build_object('result',eid);end if;
   raise exception 'Record already exists. Refresh.';
  end if;
  if eid is null or coalesce(ev,'') not in ('received','refund','deduction','interest') or amount is null or amount<=0 or (b->>'date')::date>current_date or (b->>'date')::date<'2020-01-01' or b->>'date' is null or length(trim(coalesce(b->>'reference',''))) not between 3 and 500 then raise exception 'Check amount, actual date and payment/evidence reference.';end if;
  select coalesce(sum(case when body->>'event' in ('deduction','refund') then -(body->>'amountCents')::integer else (body->>'amountCents')::integer end),0) into held from public.bp_case_records where tenancy_id=t.id and kind='deposit';
  if ev in ('refund','deduction') and amount>held then raise exception 'Amount exceeds the deposit and interest held.';end if;
  if ev='received' and amount>coalesce((t.terms->>'depositCents')::integer,0)-coalesce((select sum((body->>'amountCents')::integer) from public.bp_case_records where tenancy_id=t.id and kind='deposit' and body->>'event' in ('received','opening')),0) then raise exception 'Amount exceeds the agreed deposit still due.';end if;
  if ev='deduction' and (length(trim(coalesce(b->>'note',''))) not between 3 and 1500 or length(trim(coalesce(b->>'evidence',''))) not between 3 and 1500 or coalesce((b->>'groundsConfirmed')::boolean,false)=false) then raise exception 'Record the supported cost, reason, condition evidence and confirmed lawful grounds. Damage does not automatically forfeit the deposit.';end if;
  insert into public.bp_case_records(id,tenancy_id,kind,body,actor) values(eid,t.id,'deposit',b||jsonb_build_object('receiptDetails',public.bp_capture_receipt(t.id)),auth.uid());
  if t.tenant_id is not null then insert into public.bp_notices(user_id,title,message) values(t.tenant_id,'Security deposit updated',initcap(ev)||': R '||to_char(amount::numeric/100,'FM9999999990.00')||'. '||coalesce(b->>'note','')||case when ev='deduction' then ' Evidence: '||(b->>'evidence') else '' end);end if;
  return jsonb_build_object('result',eid);
 end if;
 r:=public.bp_action_v4(operation,args);
 if operation='tenancy' then
  select * into t from public.bp_tenancies where id=(r->>'result')::uuid;
  update public.bp_rent_terms set amount=t.rent where tenancy_id=t.id and period=date_trunc('month',t.starts)::date;
 elsif operation='property' then
  -- Removed room numbers must not retain invisible overrides.
  update public.bp_properties set room_rents=(select coalesce(jsonb_object_agg(key,value),'{}') from jsonb_each(room_rents) where key::integer<=rooms) where id=(r->>'result')::uuid;
 end if;
 return r;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;
create or replace function public.bp_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v4();
 return s||jsonb_build_object('simpleRentalsVersion',1,'properties',coalesce((select jsonb_agg(e||jsonb_build_object('roomRents',p.room_rents)) from jsonb_array_elements(s->'properties') e join public.bp_properties p on p.id=(e->>'id')::uuid),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;


-- 202611080002_south_african_dates.sql
-- South African rental dates must not be rejected during the UTC / SAST date gap.
begin;
do $$begin
 if to_regprocedure('public.bp_action_v5(text,jsonb)') is null then
  alter function public.bp_action(text,jsonb) rename to bp_action_v5;
 end if;
end $$;
revoke all on function public.bp_action_v5(text,jsonb) from public,anon,authenticated;
create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare paid date;amount integer;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.';end if;
 if operation='payment' then
  begin amount:=(args->>'amountCents')::integer;exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Enter a valid payment amount in rand.';end;
  if amount is null or amount<=0 then raise exception 'Enter a payment amount greater than R0.';end if;
  if length(trim(coalesce(args->>'payer',''))) not between 2 and 100 then raise exception 'Enter the name of the person who paid (2–100 characters).';end if;
  begin paid:=(args->>'paidOn')::date;exception when invalid_datetime_format or datetime_field_overflow then raise exception 'Choose a valid payment date.';end;
  if paid is null or paid<'2020-01-01' then raise exception 'Choose a valid payment date from 2020 onwards.';end if;
  if paid>current_date then raise exception 'The payment date is in the future. Choose today or the day you actually paid (South African time).';end if;
 end if;
 return public.bp_action_v5(operation,args);
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;
alter function public.bp_snapshot() set timezone='Africa/Johannesburg';
commit;


-- 202611110001_advance_rent.sql
-- Allow an actual payment made today/past to cover rent up to twelve months ahead.
-- Keep allocations linked to their stated month; do not move advance money into today's rent.
begin;
do $$
declare definition text;old_guard text;new_guard text;rent_guard text;
begin
 if to_regprocedure('public.bp_action_v2(text,jsonb)') is null then
  raise exception 'Apply the existing research, proration and date updates first.';
 end if;
 definition:=pg_get_functiondef('public.bp_action_v2(text,jsonb)'::regprocedure);
 old_guard:='pr>date_trunc(''month'',current_date)::date or public.bp_rent_due(t.id,pr)<=0';
 new_guard:='pr>(date_trunc(''month'',current_date)+interval ''12 months'')::date or public.bp_rent_due(t.id,pr)<=0';
 if position(old_guard in definition)>0 then
  definition:=replace(definition,old_guard,new_guard);
 elsif position(new_guard in definition)=0 then
  raise exception 'Existing month validation was not recognised; no change was applied.';
 end if;
 definition:=replace(definition,'Choose a charged rental month and positive allocation.','Choose a rent month within your tenancy and no more than 12 months ahead, with an amount greater than R0.');
 -- A future rent reduction must not leave more money assigned than the new charge.
 -- Only months governed by this new term are checked, ending at the next recorded term.
 rent_guard:=$guard$  if exists(
   select 1 from public.bp_allocations a join public.bp_payments x on x.id=a.payment_id
   where x.tenancy_id=t.id and x.state='confirmed' and a.period>=pr
    and a.period<coalesce((select min(period) from public.bp_rent_terms where tenancy_id=t.id and period>pr),'infinity'::date)
   group by a.period having sum(a.amount)>(args->>'amountCents')::integer
  ) then raise exception 'This rent change is below money already confirmed for a prepaid month. Reconcile that payment before reducing the rent.';end if;
$guard$;
 if position('This rent change is below money already confirmed for a prepaid month.' in definition)=0 then
  if position('  insert into public.bp_rent_terms values(t.id,pr,' in definition)=0 then
   raise exception 'Existing rent-term validation was not recognised; no change was applied.';
  end if;
  definition:=replace(definition,'  insert into public.bp_rent_terms values(t.id,pr,',rent_guard||'  insert into public.bp_rent_terms values(t.id,pr,');
 end if;
 -- Refunded/rejected payment history remains, but must not permanently prevent handover.
 definition:=replace(definition,
  'where x.tenancy_id=t.id and a.period>date_trunc(''month'',sd)::date)',
  'where x.tenancy_id=t.id and x.state in (''pending'',''confirmed'') and a.period>date_trunc(''month'',sd)::date)');
 execute definition;
end $$;
revoke all on function public.bp_action_v2(text,jsonb) from public,anon,authenticated;
commit;


-- 202611110002_deposit_payment_reports.sql
-- Tenant deposit reports await landlord review; only confirmation records funds held.
begin;
create table if not exists public.bp_deposit_payment_reports(
 id uuid primary key,
 tenancy_id uuid not null references public.bp_tenancies(id),
 reported_by uuid not null references public.bp_profiles(id),
 amount integer not null check(amount>0),
 paid_on date not null,
 method text not null check(method in ('Cash','Cash deposit','EFT','PayShap','Debit order','Other')),
 reference text not null check(length(reference) between 3 and 100),
 bank_reference text not null default '',
 payer text not null check(length(payer) between 2 and 100),
 notes text not null default '' check(length(notes)<=1500),
 state text not null default 'pending' check(state in ('pending','confirmed','rejected')),
 reason text not null default '',
 submitted_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references public.bp_profiles(id),
 unique(tenancy_id,reference),
 check(method not in ('Cash deposit','EFT','PayShap','Debit order') or length(bank_reference) between 3 and 150)
);
create unique index if not exists bp_deposit_report_bank_payment on public.bp_deposit_payment_reports(tenancy_id,paid_on,method,bank_reference,amount) where bank_reference<>'' and state in ('pending','confirmed');
alter table public.bp_deposit_payment_reports enable row level security;
revoke all on public.bp_deposit_payment_reports from anon,authenticated;
grant select on public.bp_deposit_payment_reports to authenticated;
drop policy if exists bp_deposit_payment_reports_read on public.bp_deposit_payment_reports;
create policy bp_deposit_payment_reports_read on public.bp_deposit_payment_reports for select to authenticated using(public.bp_sees_tenancy(tenancy_id));

do $$begin
 if to_regprocedure('public.bp_action_v6(text,jsonb)') is null then alter function public.bp_action(text,jsonb) rename to bp_action_v6;end if;
 if to_regprocedure('public.bp_snapshot_v5()') is null then alter function public.bp_snapshot() rename to bp_snapshot_v5;end if;
end $$;
revoke all on function public.bp_action_v6(text,jsonb) from public,anon,authenticated;
revoke all on function public.bp_snapshot_v5() from public,anon;
grant execute on function public.bp_snapshot_v5() to authenticated;

create or replace function public.bp_action(operation text,args jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare u public.bp_profiles;t public.bp_tenancies;p public.bp_properties;report public.bp_deposit_payment_reports;
 rid uuid;tid uuid;amount_cents integer;paid date;method_name text;record_ref text;bank_ref text;payer_name text;report_notes text;decision boolean;why text;received bigint;pending bigint;
begin
 if operation not in ('deposit_report','deposit_review') then return public.bp_action_v6(operation,args);end if;
 select * into u from public.bp_profiles where id=auth.uid();
 if not found then raise exception 'Sign in to continue.';end if;
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,0));
 if operation='deposit_report' then tid:=(args->>'tenancyId')::uuid;
 else
  select * into report from public.bp_deposit_payment_reports where id=(args->>'id')::uuid;
  if not found then raise exception 'Deposit payment report unavailable.';end if;
  tid:=report.tenancy_id;
 end if;
 select * into t from public.bp_tenancies where id=tid;
 select * into p from public.bp_properties where id=t.property_id for update;
 if not found then raise exception 'Rental unavailable.';end if;
 select * into t from public.bp_tenancies where id=tid for update;
 if operation='deposit_report' then
  if u.role<>'tenant' or t.tenant_id is distinct from u.id then raise exception 'Only the linked tenant can report this deposit payment.';end if;
  rid:=(args->>'eventId')::uuid;amount_cents:=(args->>'amountCents')::integer;paid:=(args->>'paidOn')::date;
  method_name:=args->>'method';record_ref:=trim(coalesce(args->>'reference',''));bank_ref:=trim(coalesce(args->>'bankReference',''));
  payer_name:=trim(coalesce(nullif(args->>'payer',''),u.name));report_notes:=trim(coalesce(args->>'notes',''));
  if rid is null or amount_cents is null or amount_cents<=0 or paid is null or paid<'2020-01-01' or paid>current_date
   or coalesce(method_name,'') not in ('Cash','Cash deposit','EFT','PayShap','Debit order','Other')
   or length(record_ref) not between 3 and 100 or length(payer_name) not between 2 and 100 or length(report_notes)>1500 or length(bank_ref)>150 then
   raise exception 'Check the deposit amount, date, payment method and payer.';
  end if;
  if method_name in ('Cash deposit','EFT','PayShap','Debit order') and length(bank_ref)<3 then raise exception 'Enter the bank payment reference from your banking app or deposit slip.';end if;
  select * into report from public.bp_deposit_payment_reports where id=rid;
  if found then
   if report.tenancy_id=t.id and report.reported_by=u.id and report.amount=amount_cents and report.paid_on=paid and report.method=method_name and report.reference=record_ref and report.bank_reference=bank_ref and report.payer=payer_name and report.notes=report_notes then return jsonb_build_object('result',report.id);end if;
   raise exception 'This payment report number is already in use. Refresh before trying again.';
  end if;
  if bank_ref<>'' and (exists(select 1 from public.bp_deposit_payment_reports d where d.tenancy_id=t.id and d.paid_on=paid and d.method=method_name and d.bank_reference=bank_ref and d.amount=amount_cents and d.state in ('pending','confirmed'))
   or exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='deposit' and c.body->>'event'='received' and c.body->>'reference'=bank_ref and (c.body->>'date')::date=paid and (c.body->>'amountCents')::integer=amount_cents)) then raise exception 'This bank deposit payment has already been reported or recorded.';end if;
  select coalesce(sum((body->>'amountCents')::integer),0) into received from public.bp_case_records where tenancy_id=t.id and kind='deposit' and body->>'event' in ('received','opening');
  select coalesce(sum(d.amount),0) into pending from public.bp_deposit_payment_reports d where d.tenancy_id=t.id and d.state='pending';
  if amount_cents>coalesce((t.terms->>'depositCents')::integer,0)-received-pending then raise exception 'This is more than the deposit still due after payments already received or waiting for review.';end if;
  if exists(select 1 from public.bp_deposit_payment_reports where tenancy_id=t.id and reference=record_ref) then raise exception 'This deposit payment reference has already been reported.';end if;
  insert into public.bp_deposit_payment_reports(id,tenancy_id,reported_by,amount,paid_on,method,reference,bank_reference,payer,notes)
   values(rid,t.id,u.id,amount_cents,paid,method_name,record_ref,bank_ref,payer_name,report_notes);
  insert into public.bp_notices(user_id,title,message) values(p.owner_id,'Deposit payment awaiting review',u.name||' reported R '||to_char(amount_cents::numeric/100,'FM9999999990.00')||' towards the security deposit for room '||t.room||'. Check the money received before confirming.');
  return jsonb_build_object('result',rid);
 else
  if u.role<>'landlord' or p.owner_id<>u.id then raise exception 'Only the landlord can confirm or reject a deposit payment.';end if;
  select * into report from public.bp_deposit_payment_reports where id=report.id for update;
  if coalesce(jsonb_typeof(args->'confirm'),'')<>'boolean' then raise exception 'Choose whether to confirm or reject this deposit payment.';end if;
  decision:=(args->>'confirm')::boolean;why:=trim(coalesce(args->>'reason',''));
  if not decision and length(why) not between 3 and 1500 then raise exception 'Explain why the deposit payment could not be confirmed.';end if;
  if report.state<>'pending' then
   if (decision and report.state='confirmed') or (not decision and report.state='rejected' and report.reason=why) then return jsonb_build_object('result',report.id);end if;
   raise exception 'This deposit payment has already been reviewed. Refresh its details.';
  end if;
  if decision then
   if report.bank_reference<>'' and exists(select 1 from public.bp_case_records c where c.tenancy_id=t.id and c.kind='deposit' and c.id<>report.id and c.body->>'event'='received' and c.body->>'reference'=report.bank_reference and (c.body->>'date')::date=report.paid_on and (c.body->>'amountCents')::integer=report.amount) then
    raise exception 'This bank deposit payment is already recorded as received. Reject this report as already recorded instead of confirming it again.';
   end if;
   -- Same event id on the actual ledger prevents a repeated confirmation counting twice.
   perform public.bp_action_v6('deposit_update',jsonb_build_object('tenancyId',t.id,'eventId',report.id,'body',jsonb_build_object(
    'event','received','amountCents',report.amount,'date',report.paid_on,'reference',case when report.bank_reference<>'' then report.bank_reference else report.reference end,
    'method',report.method,'payer',report.payer,'note','Tenant deposit payment confirmed by landlord. '||report.notes)));
  end if;
  update public.bp_deposit_payment_reports set state=case when decision then 'confirmed' else 'rejected' end,reason=case when decision then '' else why end,reviewed_at=now(),reviewed_by=u.id where id=report.id;
  if not decision then insert into public.bp_notices(user_id,title,message) values(report.reported_by,'Deposit payment needs attention',why);end if;
  return jsonb_build_object('result',report.id);
 end if;
end $$;
revoke all on function public.bp_action(text,jsonb) from public,anon;
grant execute on function public.bp_action(text,jsonb) to authenticated;

create or replace function public.bp_snapshot() returns jsonb
language plpgsql security invoker set search_path=public,pg_temp set timezone='Africa/Johannesburg' as $$
declare s jsonb;
begin
 s:=public.bp_snapshot_v5();
 return s||jsonb_build_object('depositPaymentReportsVersion',1,'depositPaymentReports',coalesce((select jsonb_agg(jsonb_build_object(
  'id',id,'tenancyId',tenancy_id,'amountCents',amount,'paidOn',paid_on,'method',method,'reference',reference,'bankReference',bank_reference,'payer',payer,'notes',notes,'state',state,'reason',reason,'submittedAt',submitted_at,'reviewedAt',reviewed_at) order by submitted_at,id)
  from public.bp_deposit_payment_reports),'[]'));
end $$;
revoke all on function public.bp_snapshot() from public,anon;
grant execute on function public.bp_snapshot() to authenticated;
commit;


-- 202611110003_deposit_reminders.sql
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


-- 202611110004_fixed_rental_policy.sql
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
