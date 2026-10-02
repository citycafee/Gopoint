-- ═══════════════════════════════════════════════
-- USERS DIRECTORY (Go!Point)
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- Lets the Admin → Users screen list every registered
-- user and perform WhatsApp / Gmail password resets.
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS app_users (
  id         TEXT PRIMARY KEY,              -- phone number or email used to sign up
  full_name  TEXT DEFAULT '',
  phone      TEXT DEFAULT '',
  email      TEXT DEFAULT '',
  provider   TEXT DEFAULT 'phone',          -- phone | whatsapp | email | gmail
  password   TEXT DEFAULT '',               -- current password (temporary password after a reset)
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_users_phone ON app_users (phone);
CREATE INDEX IF NOT EXISTS idx_app_users_email ON app_users (email);

ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users: public read"   ON app_users;
DROP POLICY IF EXISTS "Users: anyone insert" ON app_users;
DROP POLICY IF EXISTS "Users: anyone update" ON app_users;
DROP POLICY IF EXISTS "Users: anyone delete" ON app_users;

CREATE POLICY "Users: public read"   ON app_users FOR SELECT USING (true);
CREATE POLICY "Users: anyone insert" ON app_users FOR INSERT WITH CHECK (true);
CREATE POLICY "Users: anyone update" ON app_users FOR UPDATE USING (true);
CREATE POLICY "Users: anyone delete" ON app_users FOR DELETE USING (true);

-- Realtime: SB.sql installs an event trigger that auto-adds any
-- newly created public table to supabase_realtime, so no extra step
-- is needed if SB.sql has been run before this file.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'app_users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE app_users;
  END IF;
END $$;
