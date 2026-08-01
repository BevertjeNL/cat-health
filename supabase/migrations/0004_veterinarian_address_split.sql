-- Splits the vet's address into street and postal-code+city so they can be
-- shown on two separate lines instead of one free-text field. The old
-- `address` column stays (unused going forward) — additive only, no data to
-- migrate since this table barely has any rows yet.

alter table veterinarians add column if not exists street text;
alter table veterinarians add column if not exists postal_city text;
