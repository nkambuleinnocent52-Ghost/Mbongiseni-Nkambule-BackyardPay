do $$begin
 assert (select count(*)=2 from auth.users),'Existing accounts retained';
 assert (select count(*)=1 and sum(amount)=50000 from public.bp_allocations),'Legacy payment allocated exactly once after repeated upgrade';
 assert (select count(*)=1 and sum((body->>'amountCents')::integer)=75000 from public.bp_case_records where kind='deposit' and body->>'event'='opening'),'Opening deposit retained once, not a new receipt';
 assert (select receipt_details is null and entered_by is null and reference='LEGACY-CASH' from public.bp_payments where id='90000000-0000-0000-0000-000000000004'),'No invented old receipt snapshot';
end $$;
-- Clear only this disposable harness before independent access tests.
truncate public.bp_documents,public.bp_allocations,public.bp_case_records,public.bp_rent_terms,public.bp_payments,public.bp_notices,public.bp_tenancies,public.bp_properties,public.bp_profiles,auth.users cascade;
\echo 'Legacy upgrade preservation checks passed.'
