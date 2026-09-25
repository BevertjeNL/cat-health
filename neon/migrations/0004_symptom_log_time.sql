-- Optional time of day for afwijkingen, so an entry can record exactly when
-- a symptom was observed. Nullable: historic rows and entries without a known
-- time keep working unchanged. Idempotent so the workflow can re-run it.

alter table symptom_logs add column if not exists time time;
