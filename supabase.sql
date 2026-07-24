-- Run this in the Supabase SQL editor (project > SQL Editor > New query)

create table if not exists weight_measurements (
  id bigint generated always as identity primary key,
  date date not null,
  weight_grams integer not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists blood_values (
  id bigint generated always as identity primary key,
  date date not null,
  marker text not null,
  value numeric not null,
  unit text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists cat_profile (
  id int primary key default 1,
  name text,
  birth_date date,
  sex text check (sex in ('mannelijk', 'vrouwelijk')),
  neutered boolean,
  activity_level text check (activity_level in ('laag', 'matig', 'hoog')),
  target_min_kg numeric,
  target_max_kg numeric,
  updated_at timestamptz not null default now(),
  constraint cat_profile_single_row check (id = 1)
);

create table if not exists vaccinations (
  id bigint generated always as identity primary key,
  date date not null,
  vaccine text not null,
  valid_until date,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists weight_measurements_date_idx on weight_measurements (date);
create index if not exists blood_values_date_idx on blood_values (date);
create index if not exists blood_values_marker_idx on blood_values (marker);
create index if not exists vaccinations_date_idx on vaccinations (date);
create index if not exists vaccinations_valid_until_idx on vaccinations (valid_until);

-- No auth in this app: the anon key is used directly from the frontend.
-- Enable RLS and allow the anon role full access, since only this key is
-- ever exposed and there's no login (personal single-user app).
alter table weight_measurements enable row level security;
alter table blood_values enable row level security;
alter table cat_profile enable row level security;
alter table vaccinations enable row level security;

create policy "anon full access weight_measurements"
  on weight_measurements for all
  to anon
  using (true)
  with check (true);

create policy "anon full access blood_values"
  on blood_values for all
  to anon
  using (true)
  with check (true);

create policy "anon full access cat_profile"
  on cat_profile for all
  to anon
  using (true)
  with check (true);

create policy "anon full access vaccinations"
  on vaccinations for all
  to anon
  using (true)
  with check (true);

-- Table-level privileges: RLS policies above only take effect once the
-- anon role can touch the tables at all. Needed because "Automatically
-- expose new tables" was left off when creating the project.
grant usage on schema public to anon;
grant select, insert, update, delete on weight_measurements to anon;
grant select, insert, update, delete on blood_values to anon;
grant select, insert, update, delete on cat_profile to anon;
grant select, insert, update, delete on vaccinations to anon;
grant usage, select on all sequences in schema public to anon;
