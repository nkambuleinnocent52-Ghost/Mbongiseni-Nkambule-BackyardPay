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
