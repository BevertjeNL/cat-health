-- Enforce the domain rules that the UI already communicates. NOT VALID keeps
-- the migration safe for historic data while enforcing every new or changed
-- row immediately; legacy rows can be audited and validated separately.

begin;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'pets_positive_targets_check') then
    alter table pets add constraint pets_positive_targets_check
      check ((target_min_kg is null or target_min_kg > 0) and (target_max_kg is null or target_max_kg > 0)) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pets_target_order_check') then
    alter table pets add constraint pets_target_order_check
      check (target_min_kg is null or target_max_kg is null or target_min_kg <= target_max_kg) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pets_weight_reminder_days_check') then
    alter table pets add constraint pets_weight_reminder_days_check
      check (weight_reminder_days is null or weight_reminder_days between 1 and 3650) not valid;
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'weight_measurements_positive_check') then
    alter table weight_measurements add constraint weight_measurements_positive_check
      check (weight_grams > 0) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'food_purchases_positive_amount_check') then
    alter table food_purchases add constraint food_purchases_positive_amount_check
      check (amount_grams > 0) not valid;
  end if;
end
$$;

do $$
declare
  table_name text;
  constraint_name text;
begin
  foreach table_name in array array['vaccinations', 'medications', 'vet_visits', 'food_purchases'] loop
    constraint_name := table_name || '_nonnegative_cost_check';
    if not exists (select 1 from pg_constraint where conname = constraint_name) then
      execute format(
        'alter table %I add constraint %I check (cost is null or cost >= 0) not valid',
        table_name,
        constraint_name
      );
    end if;
  end loop;
end
$$;

commit;
