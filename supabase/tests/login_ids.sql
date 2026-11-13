-- Run after all migrations in a disposable database, never against live users.
begin;
do $$
declare account_id uuid; alias text; result jsonb; i integer;
begin
 select id into account_id from public.bp_profiles order by id limit 1;
 if account_id is null then raise exception 'Login ID tests need an existing harness account.'; end if;
 select login_id into alias from public.bp_login_ids where user_id=account_id;
 if alias !~ '^[1-9][0-9]{8}$' then raise exception 'Nine-digit ID not provisioned.'; end if;
 if public.bp_login_id_enabled() then raise exception 'Optional alias sign-in must start disabled.'; end if;
 if has_table_privilege('anon','public.bp_login_ids','select') or has_table_privilege('authenticated','public.bp_login_ids','select') then raise exception 'ID mapping table exposed.'; end if;
 if has_function_privilege('anon','public.bp_begin_login_id_attempt(text,text)','execute') or has_function_privilege('authenticated','public.bp_begin_login_id_attempt(text,text)','execute') then raise exception 'Anonymous email resolution exposed.'; end if;
 if not has_function_privilege('service_role','public.bp_begin_login_id_attempt(text,text)','execute') then raise exception 'Server cannot use limiter.'; end if;
 update public.bp_login_id_config set enabled=true where singleton;
 perform set_config('request.jwt.claim.sub',account_id::text,true);
 if public.bp_my_login_id()<>alias then raise exception 'Own ID not returned.'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 if public.bp_my_login_id() is not null then raise exception 'Another account ID leaked.'; end if;
 for i in 1..10 loop
  result:=public.bp_begin_login_id_attempt(alias,repeat('a',64));
  if result->>'allowed'<>'true' then raise exception 'Attempt % blocked too early.',i; end if;
 end loop;
 result:=public.bp_begin_login_id_attempt(alias,repeat('a',64));
 if result->>'allowed'<>'false' or result ? 'email' then raise exception 'Attempt limit did not protect identity.'; end if;
 result:=public.bp_begin_login_id_attempt('not-an-id',repeat('a',64));
 if result->>'allowed'<>'false' then raise exception 'Invalid ID accepted.'; end if;
 update public.bp_login_id_config set enabled=false where singleton;
 if public.bp_my_login_id() is not null then raise exception 'Disabled feature still advertised.'; end if;
end $$;
rollback;
