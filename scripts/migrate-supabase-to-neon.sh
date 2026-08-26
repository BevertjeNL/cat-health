#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_ACCESS_TOKEN:?Missing SUPABASE_ACCESS_TOKEN}"
: "${SUPABASE_DB_PASSWORD:?Missing SUPABASE_DB_PASSWORD}"
: "${SUPABASE_PROJECT_REF:?Missing SUPABASE_PROJECT_REF}"
: "${NEON_DATABASE_URL:?Missing NEON_DATABASE_URL}"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

supabase link --project-ref "$SUPABASE_PROJECT_REF"
supabase db dump --linked --data-only --schema public --use-copy \
  --file "$work_dir/cathealth-data.sql"

jq -n '{query: "select id::text as old_user_id, email from auth.users where email is not null order by id", read_only: true}' > "$work_dir/user-query.json"
curl --fail --silent --show-error --request POST \
  --header "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --data-binary "@$work_dir/user-query.json" \
  "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/database/query/read-only" \
  > "$work_dir/legacy-users.json"
jq -r '(if type == "array" then . else .result end)[] | [.old_user_id, .email] | @tsv' \
  "$work_dir/legacy-users.json" > "$work_dir/legacy-users.tsv"
test -s "$work_dir/legacy-users.tsv"

counts_sql="
select * from (
  select 'blood_values' as table_name, count(*)::bigint as row_count from public.blood_values
  union all select 'food_catalog', count(*) from public.food_catalog
  union all select 'food_purchases', count(*) from public.food_purchases
  union all select 'medication_catalog', count(*) from public.medication_catalog
  union all select 'medications', count(*) from public.medications
  union all select 'pets', count(*) from public.pets
  union all select 'symptom_logs', count(*) from public.symptom_logs
  union all select 'vaccinations', count(*) from public.vaccinations
  union all select 'veterinarians', count(*) from public.veterinarians
  union all select 'vet_visits', count(*) from public.vet_visits
  union all select 'weight_measurements', count(*) from public.weight_measurements
) counts order by table_name
"
jq -n --arg query "$counts_sql" '{query: $query, read_only: true}' > "$work_dir/count-query.json"
curl --fail --silent --show-error --request POST \
  --header "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --data-binary "@$work_dir/count-query.json" \
  "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/database/query/read-only" \
  > "$work_dir/source-counts.json"
jq -r '(if type == "array" then . else .result end)[] | [.table_name, .row_count] | @tsv' \
  "$work_dir/source-counts.json" > "$work_dir/source-counts.tsv"

target_table=$(psql "$NEON_DATABASE_URL" --tuples-only --no-align \
  --command="select to_regclass('public.pets')")
if [[ -z "$target_table" ]]; then
  existing=0
else
  existing=$(psql "$NEON_DATABASE_URL" --tuples-only --no-align \
    --command="select count(*) from public.pets")
fi
test "$existing" = "0"

psql "$NEON_DATABASE_URL" --set ON_ERROR_STOP=1 --file neon/migrations/0001_initial_schema.sql
psql "$NEON_DATABASE_URL" --set ON_ERROR_STOP=1 --single-transaction \
  --file "$work_dir/cathealth-data.sql"
psql "$NEON_DATABASE_URL" --set ON_ERROR_STOP=1 \
  --variable legacy_users_file="$work_dir/legacy-users.tsv" <<'SQL'
\copy cathealth_migration.legacy_users(old_user_id, email) from :'legacy_users_file' with (format csv, delimiter E'\t')
update public.pets as p
   set user_id = u.id::text
  from cathealth_migration.legacy_users as legacy
  join neon_auth."user" as u on lower(u.email) = lower(legacy.email)
 where p.user_id = legacy.old_user_id;
SQL

psql "$NEON_DATABASE_URL" --set ON_ERROR_STOP=1 --tuples-only --no-align \
  --field-separator=$'\t' > "$work_dir/target-counts.tsv" <<'SQL'
select * from (
  select 'blood_values' as table_name, count(*)::bigint as row_count from public.blood_values
  union all select 'food_catalog', count(*) from public.food_catalog
  union all select 'food_purchases', count(*) from public.food_purchases
  union all select 'medication_catalog', count(*) from public.medication_catalog
  union all select 'medications', count(*) from public.medications
  union all select 'pets', count(*) from public.pets
  union all select 'symptom_logs', count(*) from public.symptom_logs
  union all select 'vaccinations', count(*) from public.vaccinations
  union all select 'veterinarians', count(*) from public.veterinarians
  union all select 'vet_visits', count(*) from public.vet_visits
  union all select 'weight_measurements', count(*) from public.weight_measurements
) counts order by table_name;
SQL

diff --unified "$work_dir/source-counts.tsv" "$work_dir/target-counts.tsv"
awk -F '\t' '{ total += $2 } END { print "Verified " total " rows across " NR " tables" }' \
  "$work_dir/target-counts.tsv"
