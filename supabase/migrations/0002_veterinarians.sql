-- Adds a standalone vet-contacts list (name, phone, address, notes), separate
-- from vet_visits which only logs individual visit history (reason/result/
-- cost per visit, no contact details). Powers the new "Dierenartsen" card on
-- the vet tab and the printable overview.

create table if not exists veterinarians (
  id bigint generated always as identity primary key,
  pet_id bigint not null references pets (id) on delete cascade,
  name text not null,
  phone text,
  email text,
  address text,
  notes text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists veterinarians_pet_id_idx on veterinarians (pet_id);

alter table veterinarians enable row level security;

drop policy if exists "owner full access veterinarians" on veterinarians;
create policy "owner full access veterinarians"
  on veterinarians for all
  to authenticated
  using (auth.uid() = (select user_id from pets where pets.id = veterinarians.pet_id))
  with check (auth.uid() = (select user_id from pets where pets.id = veterinarians.pet_id));

grant select, insert, update, delete on veterinarians to authenticated;
grant usage, select on all sequences in schema public to authenticated;
