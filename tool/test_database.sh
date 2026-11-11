#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
container="backyardpay-sql-${RANDOM}"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run --name "$container" -e POSTGRES_HOST_AUTH_METHOD=trust -d postgres:17-alpine >/dev/null
ready=false
for attempt in {1..40}; do
  if docker exec "$container" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then ready=true;break; fi
  sleep 1
done
if [ "$ready" != true ]; then docker logs --tail 20 "$container"; exit 1; fi
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/bootstrap.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202610240001_backyardpay.sql
# Verify the migration is safe to re-run without deleting records.
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202610240001_backyardpay.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/access_and_payments.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/legacy_upgrade_fixture.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611060001_research_accounts.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611060001_research_accounts.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611060002_private_documents.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611060002_private_documents.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/legacy_upgrade_assert.sql
if [ -f supabase/tests/research_accounts.sql ]; then
 docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/research_accounts.sql
fi

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/proration_legacy_fixture.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070001_first_month_proration.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070001_first_month_proration.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/first_month_proration.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070002_deposits_and_reports.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070002_deposits_and_reports.sql
# Verify the combined owner upgrade can safely be replayed.
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070001_first_month_proration.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070002_deposits_and_reports.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposits_and_reports.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070003_invitation_only_signup.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611070003_invitation_only_signup.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/invitation_only_signup.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611080001_simple_rentals.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611080001_simple_rentals.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/simple_rentals.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611080002_south_african_dates.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611080002_south_african_dates.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/south_african_dates.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110001_advance_rent.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110001_advance_rent.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/advance_rent.sql

docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110002_deposit_payment_reports.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110002_deposit_payment_reports.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_payment_reports.sql

# Replaying the complete owner upgrade must retain the outer deposit wrapper
# after its earlier South African date wrapper is re-created.
cat supabase/migrations/202611080002_south_african_dates.sql \
    supabase/migrations/202611110001_advance_rent.sql \
    supabase/migrations/202611110002_deposit_payment_reports.sql \
  | docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/advance_rent.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_payment_reports.sql

# Ten-day deposit reminders and scheduler-independent scoped fallback.
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110003_deposit_reminders.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110003_deposit_reminders.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_reminders.sql

# Exercise pg_cron API/status in this stock image using a test-only scheduler
# contract stub; this does not claim a real hosted background scheduler ran.
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_reminder_scheduler_fixture.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110003_deposit_reminders.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110003_deposit_reminders.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_reminder_scheduler.sql

# Replay the complete four-part owner upgrade after reminders are installed:
# earlier wrapper replacements must not strand the reminder or deposit layers.
# Read source migrations so this also works from the source ZIP without downloads.
cat supabase/migrations/202611080002_south_african_dates.sql \
    supabase/migrations/202611110001_advance_rent.sql \
    supabase/migrations/202611110002_deposit_payment_reports.sql \
    supabase/migrations/202611110003_deposit_reminders.sql \
  | docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/advance_rent.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_payment_reports.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_reminders.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/deposit_reminder_scheduler.sql

# The fixed-policy migration preserves old already-charged terms before enforcing
# rent on day1 and a ten-day initial deposit deadline for new/default rentals.
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/fixed_policy_legacy_fixture.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110004_fixed_rental_policy.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202611110004_fixed_rental_policy.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/fixed_rental_policy.sql

# Complete current owner upgrade: earlier wrapper definitions must not strand
# either the fixed-policy facade or reminder snapshot after a replay.
cat supabase/migrations/202611080002_south_african_dates.sql \
    supabase/migrations/202611110001_advance_rent.sql \
    supabase/migrations/202611110002_deposit_payment_reports.sql \
    supabase/migrations/202611110003_deposit_reminders.sql \
    supabase/migrations/202611110004_fixed_rental_policy.sql \
  | docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/fixed_rental_policy.sql
