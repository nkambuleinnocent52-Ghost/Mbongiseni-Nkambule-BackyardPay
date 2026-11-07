# South African payment dates — 8 November 2026

Payment date validation previously depended on the database session timezone. Between midnight and 02:00 in South Africa, a UTC server can still be on the previous calendar day. A payment entered using today's local date could therefore be rejected as future-dated.

`downloads/BackyardPay-Date-Fix.sql` makes the main command and snapshot use Africa/Johannesburg time, including nested validation. It also separates amount, payer and date errors. Run it in the existing Supabase SQL Editor; no web upload or account reset is needed. New upgrades using the Simple Rentals combined script include this correction.

Disposable PostgreSQL checks passed for migration replay, the 01:24 SAST/previous-UTC-day boundary, acceptance of today's South African date, future-date rejection and specific amount/payer messages. Earlier authorization, accounting, room rates, deposits, notifications and invitation tests also passed. This is tested code; the hosted project changes only after its owner runs the SQL.
