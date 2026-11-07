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
