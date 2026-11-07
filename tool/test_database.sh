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
