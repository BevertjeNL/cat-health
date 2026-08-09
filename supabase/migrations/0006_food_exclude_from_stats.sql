-- Lets a food_purchases entry be excluded from the gram/dag consumption
-- statistics (dashboard tile + Voeding-tab chart) while still counting
-- towards the cost totals. Use case: a one-off bulk buy, a bag bought for a
-- different cat, a returned/refunded purchase, etc. — real money spent, but
-- not representative of normal day-to-day consumption.

alter table food_purchases add column if not exists exclude_from_stats boolean not null default false;
