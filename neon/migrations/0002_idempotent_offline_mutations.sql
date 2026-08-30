-- Give every offline-capable insert a stable client identity. A nullable
-- column keeps all historic and non-offline rows valid; the partial unique
-- indexes make a retried client mutation idempotent.

begin;

alter table weight_measurements add column if not exists client_mutation_id uuid;
alter table blood_values add column if not exists client_mutation_id uuid;
alter table vaccinations add column if not exists client_mutation_id uuid;
alter table symptom_logs add column if not exists client_mutation_id uuid;
alter table medications add column if not exists client_mutation_id uuid;
alter table vet_visits add column if not exists client_mutation_id uuid;
alter table food_purchases add column if not exists client_mutation_id uuid;

create unique index if not exists weight_measurements_client_mutation_id_idx
  on weight_measurements (client_mutation_id) where client_mutation_id is not null;
create unique index if not exists blood_values_client_mutation_id_idx
  on blood_values (client_mutation_id) where client_mutation_id is not null;
create unique index if not exists vaccinations_client_mutation_id_idx
  on vaccinations (client_mutation_id) where client_mutation_id is not null;
create unique index if not exists symptom_logs_client_mutation_id_idx
  on symptom_logs (client_mutation_id) where client_mutation_id is not null;
create unique index if not exists medications_client_mutation_id_idx
  on medications (client_mutation_id) where client_mutation_id is not null;
create unique index if not exists vet_visits_client_mutation_id_idx
  on vet_visits (client_mutation_id) where client_mutation_id is not null;
create unique index if not exists food_purchases_client_mutation_id_idx
  on food_purchases (client_mutation_id) where client_mutation_id is not null;

commit;
