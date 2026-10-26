-- Cleanup after the Supabase -> Neon cutover (27-08-2026).
-- Removes the legacy-account claim trigger, its function and the private
-- mapping schema, plus the two test pets. Idempotent so the workflow can
-- re-run it. Only merge after a final Supabase export has been archived.

drop trigger if exists cathealth_claim_legacy_pets on neon_auth."user";
drop function if exists cathealth_migration.claim_legacy_pets();
drop table if exists cathealth_migration.legacy_users;
drop schema if exists cathealth_migration;

-- Child rows are removed by the on delete cascade on every pet_id foreign key.
-- The name guard keeps this from touching any other pet that reuses an id.
delete from public.pets
where (id = 2 and name = 'TestHond')
   or (id = 3 and name = 'Test hond');
