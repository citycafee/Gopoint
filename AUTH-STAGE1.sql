-- ============================================================
-- AUTH STAGE 1 — Admin on Supabase Auth, then lock menu writes
-- Project: jynjoiidearebmpsisom
-- Run in:  Supabase Dashboard → SQL Editor → New Query
--
-- ⚠️  TWO PARTS, RUN IN THIS EXACT ORDER
-- ============================================================
--
--   PART A  →  run FIRST,  BEFORE deploying the new admin.html code.
--              Creates the `admins` table the new login checks. Until it
--              exists, admin sign-in fails closed (safe: you just can't
--              log in yet — the old login is gone either way).
--
--   [deploy the code, then verify you can log in]
--
--   PART B  →  run LAST, AFTER confirming admin login works.
--              Locks restaurant/menu writes to admins. Do not run this
--              before you have successfully signed in once with the
--              new login, or you will lock yourself out of menu edits.
--
-- Both parts are idempotent (safe to run more than once).
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- PART A — SETUP  (run before deploying)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.admins (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

-- Members can read only their own membership row. The admin portal runs
-- `select user_id from admins where user_id = auth.uid()` — a signed-in
-- non-admin gets zero rows and is rejected.
--
-- Deliberately NO insert/update/delete policies: admin rights can only be
-- granted from this SQL editor (or the service role). A signed-in user can
-- never grant themselves admin.
DROP POLICY IF EXISTS "Admins: read own" ON public.admins;
CREATE POLICY "Admins: read own"
  ON public.admins FOR SELECT
  USING (auth.uid() = user_id);


-- ── STEP A1 ── Create your admin auth account ──────────────
-- Do this in the dashboard UI (NOT SQL — Supabase manages password hashing):
--
--   Authentication  →  Users  →  Add user
--     Email:     admin@gopoint.admin        ← change to your own if you prefer
--     Password:  <choose a strong password — do NOT reuse admin123>
--     Auto Confirm User: ✅ ON
--
-- If you use a different email, substitute it in Step A2 below and in the
-- sign-in field (an email is accepted as-is; a bare username like "admin"
-- is mapped to "admin@gopoint.admin" by the client).


-- ── STEP A2 ── Grant that account admin rights ────────────
-- Run this AFTER creating the user in Step A1:
INSERT INTO public.admins (user_id)
SELECT id FROM auth.users WHERE lower(email) = 'admin@gopoint.admin'
ON CONFLICT (user_id) DO NOTHING;

-- Confirm it took (must return 1 row):
--   SELECT a.user_id, u.email FROM public.admins a
--   JOIN auth.users u ON u.id = a.user_id;


-- ════════════════════════════════════════════════════════════
-- PART B — LOCKDOWN  (run LAST, after verifying admin login)
-- ════════════════════════════════════════════════════════════

-- Helper used by the policies below. SECURITY INVOKER (the default) so that
-- RLS on `admins` still applies — it can only ever return true for the
-- caller's own row.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid())
$$;

-- ── restaurants ── public browse, admin-only write ────────
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'restaurants'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.restaurants', p.policyname);
  END LOOP;
END $$;

CREATE POLICY "Restaurants: public read"
  ON public.restaurants FOR SELECT USING (true);

CREATE POLICY "Restaurants: admin insert"
  ON public.restaurants FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "Restaurants: admin update"
  ON public.restaurants FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "Restaurants: admin delete"
  ON public.restaurants FOR DELETE USING (public.is_admin());


-- ── menu_items ── public browse, admin-only write ─────────
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'menu_items'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.menu_items', p.policyname);
  END LOOP;
END $$;

CREATE POLICY "Menu: public read"
  ON public.menu_items FOR SELECT USING (true);

CREATE POLICY "Menu: admin insert"
  ON public.menu_items FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "Menu: admin update"
  ON public.menu_items FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "Menu: admin delete"
  ON public.menu_items FOR DELETE USING (public.is_admin());


-- ── vehicles / orders / settings are NOT touched here ─────
-- Drivers and customers still write those anonymously until Stages 2 and 3
-- give them real sessions (see AUTH-PLAN.md). Locking them now would break
-- GPS updates, order status changes and profile saving.


-- ════════════════════════════════════════════════════════════
-- VERIFY  (run after Part B)
-- ════════════════════════════════════════════════════════════
--
-- 1. Browse the app as a guest — restaurant list and menus must still load.
--    (Public SELECT policies above are what allow this.)
--
-- 2. Browser console, signed OUT as admin:
--      const { data, error } = await sb.from('restaurants')
--        .update({ name: 'HACKED' }).eq('id', 'som-coffee');
--      console.log(data, error);
--    Must return an error and change nothing. Before Part B it succeeds.
--
-- 3. Sign in at /admin with your new credentials — dashboard loads, and
--    editing a restaurant still saves.
--
-- ─────────────────────────────────────────────────────────
-- ROLLBACK (restores anonymous write access):
--   DROP POLICY IF EXISTS "Restaurants: public read"   ON public.restaurants;
--   DROP POLICY IF EXISTS "Restaurants: admin insert"  ON public.restaurants;
--   DROP POLICY IF EXISTS "Restaurants: admin update"  ON public.restaurants;
--   DROP POLICY IF EXISTS "Restaurants: admin delete"  ON public.restaurants;
--   DROP POLICY IF EXISTS "Menu: public read"          ON public.menu_items;
--   DROP POLICY IF EXISTS "Menu: admin insert"         ON public.menu_items;
--   DROP POLICY IF EXISTS "Menu: admin update"         ON public.menu_items;
--   DROP POLICY IF EXISTS "Menu: admin delete"         ON public.menu_items;
--   -- then re-run the policy block from SB.sql:155-161
-- ════════════════════════════════════════════════════════════
