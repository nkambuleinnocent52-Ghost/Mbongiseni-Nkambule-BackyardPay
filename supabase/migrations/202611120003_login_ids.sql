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
