begin;

grant update (date, name, category, unit, quantity, cost, batch)
  on public.inventory_purchases to authenticated;

create or replace function public.validate_inventory_purchase_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  used_quantity numeric;
  first_use_date date;
begin
  -- Afboekingen nemen dezelfde lock, zodat een gelijktijdige wijziging de
  -- bestaande voorraad niet ongeldig kan maken.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.id::text, 8205));

  select coalesce(sum(inventory_quantity), 0), min(date)
    into used_quantity, first_use_date
    from public.inventory_uses where inventory_purchase_id = new.id;
  if old.category = 'medicine' then
    select used_quantity + coalesce(sum(inventory_quantity), 0),
           least(first_use_date, min(date))
      into used_quantity, first_use_date
      from public.medications where inventory_purchase_id = new.id;
  end if;

  if used_quantity > 0 and (new.category <> old.category or new.unit <> old.unit) then
    raise exception 'Categorie en eenheid kunnen niet worden gewijzigd na gebruik.';
  end if;
  if new.quantity < used_quantity then
    raise exception 'De hoeveelheid kan niet lager zijn dan de al gebruikte voorraad.';
  end if;
  if first_use_date is not null and new.date > first_use_date then
    raise exception 'De aankoopdatum kan niet na een gebruiksdatum liggen.';
  end if;
  return new;
end
$$;

drop trigger if exists inventory_purchases_validate_update on public.inventory_purchases;
create trigger inventory_purchases_validate_update
  before update on public.inventory_purchases
  for each row execute function public.validate_inventory_purchase_update();

notify pgrst, 'reload schema';
commit;
