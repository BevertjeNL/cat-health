-- Applied via `supabase db push` (see .github/workflows/supabase-migrations.yml)
-- or manually in the Supabase SQL editor. This is the full CURRENT schema for
-- a brand new project (multi-user, Supabase Auth + RLS keyed to auth.uid()).
--
-- Consolidated from the two legacy files that used to sit loose in the repo
-- root: supabase.sql only ever covered pets/weight_measurements/blood_values/
-- vaccinations and had drifted out of date — it was missing medications,
-- medication_catalog, symptom_logs and vet_visits, which only existed in
-- migration_multiuser.sql's STAP 7-8. This file merges both into one accurate
-- baseline. migration_multiuser.sql itself is archived (see
-- supabase/migrations_archive/) since its STAP 2-5 (backfilling an existing
-- single-user cat_profile table into pets) only applies to an old live
-- upgrade, not a fresh project.

create table if not exists pets (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
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

create table if not exists vet_visits (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  reason text,
  result text,
  note text,
  cost numeric,
  created_at timestamptz not null default now()
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
create index if not exists vet_visits_pet_id_idx on vet_visits (pet_id);
create index if not exists vet_visits_date_idx on vet_visits (date);

-- Real Supabase Auth (email/password) + per-user RLS: every table is
-- scoped to the pet's owner via pets.user_id = auth.uid(), so different
-- accounts never see each other's pets or data.
alter table pets enable row level security;
alter table weight_measurements enable row level security;
alter table blood_values enable row level security;
alter table vaccinations enable row level security;
alter table symptom_logs enable row level security;
alter table medications enable row level security;
alter table medication_catalog enable row level security;
alter table vet_visits enable row level security;

create policy "owner full access pets"
  on pets for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "owner full access weight_measurements"
  on weight_measurements for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = weight_measurements.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = weight_measurements.pet_id));

create policy "owner full access blood_values"
  on blood_values for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = blood_values.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = blood_values.pet_id));

create policy "owner full access vaccinations"
  on vaccinations for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = vaccinations.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = vaccinations.pet_id));

create policy "owner full access symptom_logs"
  on symptom_logs for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = symptom_logs.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = symptom_logs.pet_id));

create policy "owner full access medications"
  on medications for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = medications.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = medications.pet_id));

create policy "owner full access medication_catalog"
  on medication_catalog for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = medication_catalog.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = medication_catalog.pet_id));

create policy "owner full access vet_visits"
  on vet_visits for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = vet_visits.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = vet_visits.pet_id));

-- Table-level privileges: RLS policies above only take effect once the
-- authenticated role can touch the tables at all.
grant usage on schema public to authenticated;
grant select, insert, update, delete on pets to authenticated;
grant select, insert, update, delete on weight_measurements to authenticated;
grant select, insert, update, delete on blood_values to authenticated;
grant select, insert, update, delete on vaccinations to authenticated;
grant select, insert, update, delete on symptom_logs to authenticated;
grant select, insert, update, delete on medications to authenticated;
grant select, insert, update, delete on medication_catalog to authenticated;
grant select, insert, update, delete on vet_visits to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- The anon role has no access at all now that login is required.
