-- Adds voeding (food) tracking: a purchase log (food_purchases, mirrors
-- vet_visits/medications — date, cost, note per entry) plus a reusable
-- catalog (food_catalog, mirrors medication_catalog) so product name +
-- droog/nat + shop combos already entered once come back as suggestions on
-- the next purchase ("herhaal aankoop"). Amounts are always stored in grams
-- (amount_grams), same convention as weight_measurements.weight_grams — the
-- UI lets the user type either grams or kilograms and converts on save.

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
  created_at timestamptz not null default now()
);

create index if not exists food_catalog_pet_id_idx on food_catalog (pet_id);
create index if not exists food_purchases_pet_id_idx on food_purchases (pet_id);
create index if not exists food_purchases_date_idx on food_purchases (date);

alter table food_catalog enable row level security;
alter table food_purchases enable row level security;

drop policy if exists "owner full access food_catalog" on food_catalog;
create policy "owner full access food_catalog"
  on food_catalog for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = food_catalog.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = food_catalog.pet_id));

drop policy if exists "owner full access food_purchases" on food_purchases;
create policy "owner full access food_purchases"
  on food_purchases for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = food_purchases.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = food_purchases.pet_id));

grant select, insert, update, delete on food_catalog to authenticated;
grant select, insert, update, delete on food_purchases to authenticated;
grant usage, select on all sequences in schema public to authenticated;
