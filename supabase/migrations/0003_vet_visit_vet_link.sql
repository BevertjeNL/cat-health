-- Links a vet visit to an entry in the veterinarians contact list, so a new
-- visit can select "which vet" instead of typing it loose into a note.
-- `set null` (not cascade) on delete — removing a vet from the contact list
-- must not take its visit history with it.

alter table vet_visits add column if not exists vet_id bigint references veterinarians (id) on delete set null;

create index if not exists vet_visits_vet_id_idx on vet_visits (vet_id);
