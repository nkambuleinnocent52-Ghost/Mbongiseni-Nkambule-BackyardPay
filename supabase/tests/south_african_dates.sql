\set ON_ERROR_STOP on
begin;
-- Model the screenshot: 01:24 SAST is still the previous UTC date.
do $$begin
 assert ('2026-11-07 23:24:00+00'::timestamptz at time zone 'Africa/Johannesburg')::date='2026-11-08';
 assert ('2026-11-07 23:24:00+00'::timestamptz at time zone 'UTC')::date='2026-11-07';
 assert (select 'TimeZone=Africa/Johannesburg'=any(proconfig) from pg_proc where oid='public.bp_action(text,jsonb)'::regprocedure);
end $$;
set local timezone='UTC';
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
select public.bp_action('property','{"id":"70000000-0000-0000-0000-000000000002","name":"Date test","address":"1 Test Street","suburb":"Area","city":"East London","postalCode":"5201","rooms":30,"rentCents":150000,"dueDay":1,"securityDepositCents":0}');
select public.bp_action('tenancy',jsonb_build_object('propertyId','70000000-0000-0000-0000-000000000002','name','Date tenant','room',28,'start',(now() at time zone 'Africa/Johannesburg')::date));
select id as tid from public.bp_tenancies where room=28 \gset
select public.bp_action('payment',jsonb_build_object('tenancyId',:'tid','amountCents',10000,'method','Cash','reference','SAST-DATE-TEST','payer','Date tenant','paidOn',(now() at time zone 'Africa/Johannesburg')::date,'received',true,'allocations','[]'::jsonb));
do $$begin
 begin perform public.bp_action('payment',jsonb_build_object('amountCents',10000,'payer','Date tenant','paidOn',(now() at time zone 'Africa/Johannesburg')::date+1));raise exception 'FAIL: future date';exception when raise_exception then assert sqlerrm like 'The payment date is in the future.%';end;
 begin perform public.bp_action('payment',jsonb_build_object('amountCents',0));raise exception 'FAIL: amount';exception when raise_exception then assert sqlerrm='Enter a payment amount greater than R0.';end;
 begin perform public.bp_action('payment',jsonb_build_object('amountCents',10000,'payer','X'));raise exception 'FAIL: payer';exception when raise_exception then assert sqlerrm like 'Enter the name of the person who paid%';end;
end $$;
rollback;
\echo 'South African date checks passed: UTC/SAST boundary, today accepted, future date rejected, specific amount/payer/date errors.'
