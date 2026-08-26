-- CatHealth baseline for Neon Postgres + Neon Auth + Data API.
-- Apply after Neon Auth and the Data API have been enabled for the branch.
-- User ids are text because Neon Auth / Better Auth ids are not UUID-only.

begin;

create table if not exists pets (
  id bigint generated always as identity primary key,
  user_id text not null,
  name text not null,
  species text not null check (species in ('kat', 'hond', 'overig')),
  breed text,
  birth_date date,
  sex text check (sex in ('mannelijk', 'vrouwelijk')),
  neutered boolean,
  activity_level text check (activity_level in ('laag', 'matig', 'hoog')),
  target_min_kg numeric,
  target_max_kg numeric,
  photo_data_url text,
  weight_reminder_days integer,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists weight_measurements (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  weight_grams integer not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists blood_values (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  marker text not null,
  value numeric not null,
  unit text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists vaccinations (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  vaccine text not null,
  valid_until date,
  note text,
  cost numeric,
  no_repeat boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists symptom_logs (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  symptom text not null,
  severity text check (severity in ('licht', 'matig', 'ernstig')),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists medications (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  name text not null,
  dose text,
  next_due_date date,
  note text,
  purpose text,
  brand text,
  active_ingredient text,
  batch text,
  cost numeric,
  created_at timestamptz not null default now()
);

create table if not exists medication_catalog (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  name text not null,
  purpose text,
  brand text,
  active_ingredient text,
  dose text,
  created_at timestamptz not null default now()
);

create table if not exists veterinarians (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  name text not null,
  phone text,
  email text,
  address text,
  notes text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  street text,
  postal_city text
);

create table if not exists vet_visits (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  reason text,
  result text,
  note text,
  cost numeric,
  created_at timestamptz not null default now(),
  vet_id bigint references veterinarians (id) on delete set null
);

create table if not exists food_catalog (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  name text not null,
  food_type text not null check (food_type in ('droog', 'nat')),
  shop text,
  created_at timestamptz not null default now()
);

create table if not exists food_purchases (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  name text not null,
  food_type text not null check (food_type in ('droog', 'nat')),
  amount_grams numeric not null,
  shop text,
  cost numeric,
  note text,
  created_at timestamptz not null default now(),
  exclude_from_stats boolean not null default false
);

create index if not exists pets_user_id_idx on pets (user_id);
create index if not exists weight_measurements_pet_id_idx on weight_measurements (pet_id);
create index if not exists weight_measurements_date_idx on weight_measurements (date);
create index if not exists blood_values_pet_id_idx on blood_values (pet_id);
create index if not exists blood_values_date_idx on blood_values (date);
create index if not exists blood_values_marker_idx on blood_values (marker);
create index if not exists vaccinations_pet_id_idx on vaccinations (pet_id);
create index if not exists vaccinations_date_idx on vaccinations (date);
create index if not exists vaccinations_valid_until_idx on vaccinations (valid_until);
create index if not exists symptom_logs_pet_id_idx on symptom_logs (pet_id);
create index if not exists symptom_logs_date_idx on symptom_logs (date);
create index if not exists medications_pet_id_idx on medications (pet_id);
create index if not exists medications_date_idx on medications (date);
create index if not exists medications_next_due_date_idx on medications (next_due_date);
create index if not exists medication_catalog_pet_id_idx on medication_catalog (pet_id);
create index if not exists veterinarians_pet_id_idx on veterinarians (pet_id);
create index if not exists vet_visits_pet_id_idx on vet_visits (pet_id);
create index if not exists vet_visits_date_idx on vet_visits (date);
create index if not exists vet_visits_vet_id_idx on vet_visits (vet_id);
create index if not exists food_catalog_pet_id_idx on food_catalog (pet_id);
create index if not exists food_purchases_pet_id_idx on food_purchases (pet_id);
create index if not exists food_purchases_date_idx on food_purchases (date);

alter table pets enable row level security;
alter table weight_measurements enable row level security;
alter table blood_values enable row level security;
alter table vaccinations enable row level security;
alter table symptom_logs enable row level security;
alter table medications enable row level security;
alter table medication_catalog enable row level security;
alter table veterinarians enable row level security;
alter table vet_visits enable row level security;
alter table food_catalog enable row level security;
alter table food_purchases enable row level security;

drop policy if exists "owner full access pets" on pets;
create policy "owner full access pets"
  on pets for all to authenticated
  using ((select auth.user_id()) = user_id)
  with check ((select auth.user_id()) = user_id);

drop policy if exists "owner full access weight_measurements" on weight_measurements;
create policy "owner full access weight_measurements"
  on weight_measurements for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = weight_measurements.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = weight_measurements.pet_id));

drop policy if exists "owner full access blood_values" on blood_values;
create policy "owner full access blood_values"
  on blood_values for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = blood_values.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = blood_values.pet_id));

drop policy if exists "owner full access vaccinations" on vaccinations;
create policy "owner full access vaccinations"
  on vaccinations for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = vaccinations.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = vaccinations.pet_id));

drop policy if exists "owner full access symptom_logs" on symptom_logs;
create policy "owner full access symptom_logs"
  on symptom_logs for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = symptom_logs.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = symptom_logs.pet_id));

drop policy if exists "owner full access medications" on medications;
create policy "owner full access medications"
  on medications for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = medications.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = medications.pet_id));

drop policy if exists "owner full access medication_catalog" on medication_catalog;
create policy "owner full access medication_catalog"
  on medication_catalog for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = medication_catalog.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = medication_catalog.pet_id));

drop policy if exists "owner full access veterinarians" on veterinarians;
create policy "owner full access veterinarians"
  on veterinarians for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = veterinarians.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = veterinarians.pet_id));

drop policy if exists "owner full access vet_visits" on vet_visits;
create policy "owner full access vet_visits"
  on vet_visits for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = vet_visits.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = vet_visits.pet_id));

drop policy if exists "owner full access food_catalog" on food_catalog;
create policy "owner full access food_catalog"
  on food_catalog for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = food_catalog.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = food_catalog.pet_id));

drop policy if exists "owner full access food_purchases" on food_purchases;
create policy "owner full access food_purchases"
  on food_purchases for all to authenticated
  using ((select auth.user_id()) = (select user_id from pets where pets.id = food_purchases.pet_id))
  with check ((select auth.user_id()) = (select user_id from pets where pets.id = food_purchases.pet_id));

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Temporary ownership bridge for the Supabase -> Neon Auth cutover. The
-- one-time migration imports old user ids and e-mail addresses here. When a
-- person registers the same address in Neon Auth, their pets are reassigned
-- immediately, before the new session performs its first Data API query.
-- This schema is private: it is not exposed by the Data API and no client
-- role receives privileges on it.
create schema if not exists cathealth_migration;
revoke all on schema cathealth_migration from public, anonymous, authenticated;

create table if not exists cathealth_migration.legacy_users (
  old_user_id text primary key,
  email text not null unique
);
revoke all on cathealth_migration.legacy_users from public, anonymous, authenticated;

create or replace function cathealth_migration.claim_legacy_pets()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, cathealth_migration
as $$
begin
  update public.pets
     set user_id = new.id::text
   where user_id = (
     select old_user_id
       from cathealth_migration.legacy_users
      where lower(email) = lower(new.email)
   );
  return new;
end;
$$;
revoke all on function cathealth_migration.claim_legacy_pets() from public, anonymous, authenticated;

drop trigger if exists cathealth_claim_legacy_pets on neon_auth."user";
create trigger cathealth_claim_legacy_pets
after insert or update of email on neon_auth."user"
for each row execute function cathealth_migration.claim_legacy_pets();

commit;
