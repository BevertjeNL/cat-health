-- ============================================================
-- Multi-user / multi-pet migratie (stap A)
-- Voer dit STAP VOOR STAP uit in Supabase SQL Editor.
-- Elke stap staat gemarkeerd met STAP 1, STAP 2, ... — niet
-- alles in één keer plakken, want stap 2 heeft handwerk nodig.
-- ============================================================


-- ------------------------------------------------------------
-- STAP 1: pets-tabel aanmaken + pet_id kolommen toevoegen
-- Dit is 100% veilig om nu te draaien: voegt alleen iets toe,
-- breekt niets aan de huidige (nog werkende) app.
-- ------------------------------------------------------------

create table if not exists pets (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete cascade,
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

create index if not exists pets_user_id_idx on pets (user_id);

alter table weight_measurements add column if not exists pet_id bigint references pets (id) on delete cascade;
alter table blood_values add column if not exists pet_id bigint references pets (id) on delete cascade;
alter table vaccinations add column if not exists pet_id bigint references pets (id) on delete cascade;

create index if not exists weight_measurements_pet_id_idx on weight_measurements (pet_id);
create index if not exists blood_values_pet_id_idx on blood_values (pet_id);
create index if not exists vaccinations_pet_id_idx on vaccinations (pet_id);


-- ------------------------------------------------------------
-- STAP 2: jouw eigen login-account aanmaken (handwerk, eenmalig)
-- Ga naar Supabase Dashboard > Authentication > Users > Add user
-- en maak daar JEZELF aan met je eigen e-mailadres + wachtwoord.
-- (Dit doe je zelf in de Supabase UI — dit is niet iets wat via
-- SQL of door mij gedaan wordt.)
--
-- Draai daarna onderstaande query om je nieuwe user-UUID op te
-- zoeken, en kopieer die UUID naar STAP 3 hieronder.
-- ------------------------------------------------------------

select id, email from auth.users;


-- ------------------------------------------------------------
-- STAP 3: Bailey koppelen aan jouw account (backfill bestaande data)
-- Vervang <JOUW-USER-UUID> hieronder met de UUID uit STAP 2.
-- ------------------------------------------------------------

insert into pets (user_id, name, species, birth_date, sex, neutered, activity_level, target_min_kg, target_max_kg)
select '<JOUW-USER-UUID>'::uuid, coalesce(name, 'Bailey'), 'kat', birth_date, sex, neutered, activity_level, target_min_kg, target_max_kg
from cat_profile
where id = 1
returning id;

-- Noteer de "id" die de vorige query teruggeeft (bijv. 1) en gebruik
-- die hieronder in plaats van <BAILEY-PET-ID>.

update weight_measurements set pet_id = <BAILEY-PET-ID> where pet_id is null;
update blood_values set pet_id = <BAILEY-PET-ID> where pet_id is null;
update vaccinations set pet_id = <BAILEY-PET-ID> where pet_id is null;


-- ------------------------------------------------------------
-- STAP 4: pet_id verplicht maken + RLS omzetten naar auth.uid()
-- LET OP: pas dit uitvoeren zodra de login-UI in de app (stap B)
-- ook klaar en live staat. Zodra dit draait, werkt de huidige
-- live app NIET meer met de anon-key zonder login — dus dit is
-- de stap die je samen met de deploy van de login-functionaliteit
-- moet draaien, niet los vooruit.
-- ------------------------------------------------------------

alter table weight_measurements alter column pet_id set not null;
alter table blood_values alter column pet_id set not null;
alter table vaccinations alter column pet_id set not null;
alter table pets alter column user_id set not null;
alter table pets enable row level security;

drop policy if exists "anon full access weight_measurements" on weight_measurements;
drop policy if exists "anon full access blood_values" on blood_values;
drop policy if exists "anon full access vaccinations" on vaccinations;
drop policy if exists "anon full access cat_profile" on cat_profile;

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

grant usage on schema public to authenticated;
grant select, insert, update, delete on pets to authenticated;
grant select, insert, update, delete on weight_measurements to authenticated;
grant select, insert, update, delete on blood_values to authenticated;
grant select, insert, update, delete on vaccinations to authenticated;
grant usage, select on all sequences in schema public to authenticated;

revoke all on weight_measurements from anon;
revoke all on blood_values from anon;
revoke all on vaccinations from anon;
revoke all on cat_profile from anon;


-- ------------------------------------------------------------
-- STAP 5 (optioneel, opruimen): oude cat_profile-tabel verwijderen
-- Pas doen als je zeker weet dat alles goed werkt via pets.
-- ------------------------------------------------------------

-- drop table if exists cat_profile;


-- ------------------------------------------------------------
-- STAP 6: huisdierfoto (opgeslagen als comprimeerde data-URL,
-- geen aparte Storage-bucket nodig — simpeler en erft dezelfde
-- RLS als de rest van de pets-tabel).
-- Veilig om nu te draaien, additief.
-- ------------------------------------------------------------

alter table pets add column if not exists photo_data_url text;


-- ------------------------------------------------------------
-- STAP 7: logboeken voor afwijkingen (symptomen) en medicatie.
-- Veilig om nu te draaien, additief. Volgt exact hetzelfde
-- eigenaarschap-patroon (pet_id -> auth.uid() via pets) als de
-- rest van de app.
-- ------------------------------------------------------------

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
  created_at timestamptz not null default now()
);

create index if not exists symptom_logs_pet_id_idx on symptom_logs (pet_id);
create index if not exists symptom_logs_date_idx on symptom_logs (date);
create index if not exists medications_pet_id_idx on medications (pet_id);
create index if not exists medications_date_idx on medications (date);
create index if not exists medications_next_due_date_idx on medications (next_due_date);

alter table symptom_logs enable row level security;
alter table medications enable row level security;

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

grant select, insert, update, delete on symptom_logs to authenticated;
grant select, insert, update, delete on medications to authenticated;
grant usage, select on all sequences in schema public to authenticated;


-- ------------------------------------------------------------
-- STAP 8: dashboard-ondersteuning — medicatie-catalogus (met doel,
-- voor hergebruik/dropdown), dierenarts-bezoeken-logboek, en een
-- instelbare gewicht-herinneringstermijn per huisdier.
-- Veilig om nu te draaien, additief.
-- ------------------------------------------------------------

create table if not exists medication_catalog (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  name text not null,
  purpose text,
  created_at timestamptz not null default now()
);

create table if not exists vet_visits (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  date date not null,
  reason text,
  result text,
  note text,
  created_at timestamptz not null default now()
);

alter table medications add column if not exists purpose text;
alter table pets add column if not exists weight_reminder_days integer;

create index if not exists medication_catalog_pet_id_idx on medication_catalog (pet_id);
create index if not exists vet_visits_pet_id_idx on vet_visits (pet_id);
create index if not exists vet_visits_date_idx on vet_visits (date);

alter table medication_catalog enable row level security;
alter table vet_visits enable row level security;

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

grant select, insert, update, delete on medication_catalog to authenticated;
grant select, insert, update, delete on vet_visits to authenticated;
grant usage, select on all sequences in schema public to authenticated;


-- ------------------------------------------------------------
-- STAP 9: huisdierprofiel archiveren (soft-delete i.p.v. definitief
-- verwijderen). Veilig om nu te draaien, additief. Een gearchiveerd
-- profiel wordt door de app uit het dashboard/huisdier-menu gefilterd,
-- maar blijft in de database staan en is terug te zetten.
-- ------------------------------------------------------------

alter table pets add column if not exists archived_at timestamptz;


-- ------------------------------------------------------------
-- STAP 10: medicijn-datalijst uitbreiden met merk, werkzame stof en
-- dosering (herbruikbare eigenschappen van het medicijn zelf) en batch
-- op de toegediend-log (verschilt per verpakking, dus geen catalogus-
-- eigenschap). Veilig om nu te draaien, additief.
-- ------------------------------------------------------------

alter table medication_catalog add column if not exists brand text;
alter table medication_catalog add column if not exists active_ingredient text;
alter table medication_catalog add column if not exists dose text;

alter table medications add column if not exists brand text;
alter table medications add column if not exists active_ingredient text;
alter table medications add column if not exists batch text;


-- ------------------------------------------------------------
-- STAP 11: kosten bijhouden per dierenartsbezoek/medicatie/vaccinatie,
-- voor het kosten-overzicht op het dashboard. Veilig om nu te draaien,
-- additief.
-- ------------------------------------------------------------

alter table vet_visits add column if not exists cost numeric;
alter table medications add column if not exists cost numeric;
alter table vaccinations add column if not exists cost numeric;


-- ------------------------------------------------------------
-- STAP 12: vaccinatie handmatig kunnen uitsluiten van het overzicht/
-- herinneringen ("geen vervolg nodig"). Nodig voor een oude eenmalige
-- vaccinatie (andere naam, nooit herhaald) die anders permanent als
-- openstaand/verlopen blijft meetellen. Veilig om nu te draaien, additief.
-- ------------------------------------------------------------

alter table vaccinations add column if not exists no_repeat boolean not null default false;
