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
