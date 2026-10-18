-- ============================================================
-- Go!point — RLS hardening (profiles lockdown)
-- Project: jynjoiidearebmpsisom
-- Run in:  Supabase Dashboard → SQL Editor → New Query
--
-- Idempotent: safe to run more than once.
-- ============================================================
--
-- WHY ONLY `profiles` HERE
-- -----------------------
-- The rest of the app performs every write with the public anon key and
-- no Supabase Auth session (admin signs in via localStorage, drivers via
-- PIN, customers via a custom username/phone + password store). Because
-- of that, `auth.uid()` is NULL for those flows and RLS cannot tell an
-- admin or driver apart from an attacker. Locking those tables here would
-- break the running app, so they are left as-is and documented below.
--
-- `profiles` is different: the app ONLY ever reads and writes the row
-- belonging to the signed-in Google user (`.eq('id', ownId)`), and all
-- Google traffic carries a real auth.uid(). So it can be locked with
-- zero breakage — this is a straight privacy win.
--
-- Verified against the live schema (profiles columns):
--   id, full_name, phone, avatar_url, created_at, email, address
-- NOTE: there is no `area` and no `registered_at` column on `profiles`.
--       Do not upsert those fields — PostgREST rejects them (42703).
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop any pre-existing policies so this converges to a known state.
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', p.policyname);
  END LOOP;
END $$;

-- Owner-only access. Google sign-in sets auth.uid() to the same UUID that
-- is stored in profiles.id, so each user sees exactly their own row.
CREATE POLICY "Profiles: owner select"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Profiles: owner insert"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Profiles: owner update"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Profiles: owner delete"
  ON public.profiles FOR DELETE
  USING (auth.uid() = id);

-- Signup still works: handle_new_user() is SECURITY DEFINER, so the trigger
-- that creates the profile row on auth.users insert bypasses these policies.

-- ============================================================
-- INTENTIONALLY LEFT OPEN (and why)
-- ============================================================
-- restaurants  SELECT/INSERT/UPDATE/DELETE : public browse + anonymous admin CRUD
-- menu_items   SELECT/INSERT/UPDATE/DELETE : public browse + anonymous admin CRUD
-- vehicles     SELECT/INSERT/UPDATE/DELETE : driver PIN login + GPS push + admin CRUD
-- orders       SELECT/INSERT/UPDATE/DELETE : customer checkout, driver status + delete
-- settings     SELECT/INSERT/UPDATE        : public system config + account store
--
-- `settings` already has NO delete policy, which is why DELETE silently
-- removes nothing there. Do not add one.
--
-- REMAINING EXPOSURE (needs a code change to fix, not more SQL):
--   1. settings / usr:<id> rows store PLAINTEXT passwords and are readable
--      by the anon key — the customer login downloads all of them and
--      compares client-side. Fixing this means moving login to Supabase
--      Auth (or a SECURITY DEFINER function) so passwords never leave DB.
--   2. vehicles.driver_pin is readable by anyone.
--   3. orders exposes customer names/phones/addresses to anyone.
--   4. Anyone with the anon key can insert/update restaurants, menu_items,
--      vehicles, orders and settings. Fixing this means giving the admin
--      and driver portals a real Supabase Auth session, then changing these
--      policies to `auth.uid() IS NOT NULL` (or an is_admin claim).
-- ============================================================

-- ─────────────────────────────────────────────
-- VERIFY (run after applying)
-- ─────────────────────────────────────────────
-- This must return 0 rows when called with the anon key from the browser
-- console. If it returns data, the policies did not apply:
--
--   const { data } = await sb.from('profiles').select('*');
--   console.log('profiles readable without auth:', data);
--
-- And the list of policies now on profiles:
--
--   SELECT policyname, cmd FROM pg_policies
--   WHERE schemaname='public' AND tablename='profiles';
-- ═══════════════════════════════════════════════
