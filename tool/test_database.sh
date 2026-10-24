#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
container="backyardpay-sql-${RANDOM}"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run --name "$container" -e POSTGRES_HOST_AUTH_METHOD=trust -d postgres:17-alpine >/dev/null
for attempt in {1..30}; do
  if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/bootstrap.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202610240001_backyardpay.sql
# Verify the migration is safe to re-run without deleting records.
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/202610240001_backyardpay.sql
docker exec -i "$container" psql -X -v ON_ERROR_STOP=1 -U postgres < supabase/tests/access_and_payments.sql
