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
