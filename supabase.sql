-- Run this in the Supabase SQL editor (project > SQL Editor > New query)
-- This reflects the CURRENT schema (multi-user, Supabase Auth + RLS keyed
-- to auth.uid()). If you're setting up a brand new project from scratch,
-- this is the full schema to run. If you're migrating an existing
-- single-user install, use migration_multiuser.sql instead (STAP 1-5).

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

-- Real Supabase Auth (email/password) + per-user RLS: every table is
-- scoped to the pet's owner via pets.user_id = auth.uid(), so different
-- accounts never see each other's pets or data.
alter table pets enable row level security;
alter table weight_measurements enable row level security;
alter table blood_values enable row level security;
alter table vaccinations enable row level security;

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

-- Table-level privileges: RLS policies above only take effect once the
-- authenticated role can touch the tables at all.
grant usage on schema public to authenticated;
grant select, insert, update, delete on pets to authenticated;
grant select, insert, update, delete on weight_measurements to authenticated;
grant select, insert, update, delete on blood_values to authenticated;
grant select, insert, update, delete on vaccinations to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- The anon role has no access at all now that login is required.
