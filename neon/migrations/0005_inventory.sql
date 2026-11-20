begin;

create table if not exists public.inventory_purchases (
  id uuid primary key default gen_random_uuid(),
  pet_id bigint not null references public.pets(id) on delete cascade,
  date date not null,
  name text not null check (length(trim(name)) between 1 and 160),
  category text not null check (category in ('medicine', 'litter', 'other')),
  unit text not null check (unit in ('pipet', 'tablet', 'stuk', 'zak', 'pak', 'kg', 'liter', 'ml')),
  quantity numeric(12,3) not null check (quantity > 0 and quantity < 'NaN'::numeric),
  cost numeric(10,2) not null check (cost >= 0 and cost < 'NaN'::numeric),
  batch text,
  created_at timestamptz not null default now(),
  unique (id, pet_id),
  check (unit in ('kg', 'liter', 'ml') or quantity = trunc(quantity))
);

create table if not exists public.inventory_uses (
  id uuid primary key default gen_random_uuid(),
  pet_id bigint not null references public.pets(id) on delete cascade,
  inventory_purchase_id uuid not null,
  date date not null,
  inventory_quantity numeric(12,3) not null,
  created_at timestamptz not null default now(),
  foreign key (inventory_purchase_id, pet_id)
    references public.inventory_purchases(id, pet_id) on delete cascade
);

alter table public.medications
  add column if not exists inventory_purchase_id uuid,
  add column if not exists inventory_quantity numeric(12,3);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'medications_inventory_purchase_fk' and conrelid = 'public.medications'::regclass) then
    alter table public.medications add constraint medications_inventory_purchase_fk
      foreign key (inventory_purchase_id, pet_id)
      references public.inventory_purchases(id, pet_id) on delete cascade;
  end if;
end
$$;

create index if not exists inventory_purchases_pet_idx on public.inventory_purchases(pet_id);
create index if not exists inventory_uses_pet_idx on public.inventory_uses(pet_id);
create index if not exists inventory_uses_purchase_idx on public.inventory_uses(inventory_purchase_id);
create index if not exists medications_inventory_purchase_idx on public.medications(inventory_purchase_id)
  where inventory_purchase_id is not null;

alter table public.inventory_purchases enable row level security;
alter table public.inventory_uses enable row level security;

drop policy if exists inventory_purchases_owner on public.inventory_purchases;
create policy inventory_purchases_owner on public.inventory_purchases
  for all to authenticated
  using ((select auth.user_id()) = (select user_id from public.pets where id = pet_id))
  with check ((select auth.user_id()) = (select user_id from public.pets where id = pet_id));

drop policy if exists inventory_uses_owner on public.inventory_uses;
create policy inventory_uses_owner on public.inventory_uses
  for all to authenticated
  using ((select auth.user_id()) = (select user_id from public.pets where id = pet_id))
  with check ((select auth.user_id()) = (select user_id from public.pets where id = pet_id));

revoke all on public.inventory_purchases, public.inventory_uses from authenticated;
grant select, insert on public.inventory_purchases, public.inventory_uses to authenticated;

create or replace function public.validate_inventory_use()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  purchase public.inventory_purchases%rowtype;
  used numeric;
  is_medicine boolean := tg_table_name = 'medications';
begin
  if tg_op = 'UPDATE' then
    if old.inventory_purchase_id is not null and
       (new.inventory_purchase_id is distinct from old.inventory_purchase_id or new.pet_id is distinct from old.pet_id) then
      raise exception 'De gekoppelde verpakking kan niet worden gewijzigd.';
    end if;
  end if;

  if new.inventory_purchase_id is null and new.inventory_quantity is null and is_medicine then
    return new;
  end if;

  -- Serialiseer de afboekingen van dezelfde verpakking, ook tussen apparaten.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.inventory_purchase_id::text, 8205));
  select * into purchase from public.inventory_purchases
    where id = new.inventory_purchase_id and pet_id = new.pet_id;

  if not found or (purchase.category = 'medicine') <> is_medicine then
    raise exception 'Kies een geldige verpakking.';
  end if;
  if new.date < purchase.date then
    raise exception 'De gebruiksdatum ligt vóór de aankoopdatum.';
  end if;
  if new.inventory_quantity is null or new.inventory_quantity <= 0 or new.inventory_quantity = 'NaN'::numeric
     or (purchase.unit not in ('kg', 'liter', 'ml') and new.inventory_quantity <> trunc(new.inventory_quantity)) then
    raise exception 'Kies een geldige hoeveelheid.';
  end if;

  if is_medicine then
    select coalesce(sum(inventory_quantity), 0) into used from public.medications
      where inventory_purchase_id = purchase.id and id is distinct from new.id;
    new.cost := null;
  else
    select coalesce(sum(inventory_quantity), 0) into used from public.inventory_uses
      where inventory_purchase_id = purchase.id and id is distinct from new.id;
  end if;
  if used + new.inventory_quantity > purchase.quantity then
    raise exception 'Er is onvoldoende voorraad voor deze afboeking.';
  end if;
  return new;
end
$$;

drop trigger if exists medications_inventory_use on public.medications;
create trigger medications_inventory_use before insert or update on public.medications
  for each row execute function public.validate_inventory_use();

drop trigger if exists inventory_uses_validate on public.inventory_uses;
create trigger inventory_uses_validate before insert on public.inventory_uses
  for each row execute function public.validate_inventory_use();

notify pgrst, 'reload schema';
commit;
