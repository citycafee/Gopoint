-- ============================================================
-- Go!point — Auto-enable Supabase Realtime on ALL public tables
-- Safe to run multiple times. Does NOT drop or change data.
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1) Add every existing public table to supabase_realtime (idempotent)
DO $$
DECLARE
  t text;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- 2) Event trigger: any future CREATE TABLE is added automatically
CREATE OR REPLACE FUNCTION public.auto_add_table_to_realtime()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN
    SELECT * FROM pg_event_trigger_ddl_commands()
    WHERE command_tag = 'CREATE TABLE'
      AND object_type = 'table'
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %s', obj.object_identity);
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN undefined_object THEN NULL;
    END;
  END LOOP;
END;
$$;

DROP EVENT TRIGGER IF EXISTS trg_auto_realtime_tables;
CREATE EVENT TRIGGER trg_auto_realtime_tables
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE')
EXECUTE FUNCTION public.auto_add_table_to_realtime();

-- Verify
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
