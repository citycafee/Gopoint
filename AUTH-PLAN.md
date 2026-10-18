# Auth Migration — Scope & Plan

Status: **PLANNED — not started.** Nothing here has been implemented.

Companion to `RLS.sql` (the `profiles` lockdown, which is done and unrelated to the
identity work below).

---

## 1. The problem in one paragraph

Every table except `profiles` is world-writable with the public anon key, because
the app establishes no Supabase Auth session for admin, drivers, or password/WhatsApp
customers. `auth.uid()` is therefore `NULL` for those flows, and an RLS policy can
not distinguish a legitimate admin from an attacker holding the same public key.
Writing tighter policies today would simply break the site. Identity has to come
first — then the policies follow.

---

## 2. What each role actually presents as identity today

| Role | Sign-in | Identity handed to Supabase | Reference |
|---|---|---|---|
| **Admin** | Hardcoded `admin` / `admin123` in public JS | none — a forgeable `localStorage['admin_auth']` flag | `admin.html:1817-1833`, gate `admin.html:2246-2251`, `index.html:4921-4934` |
| **Driver** | username/phone + 4-digit PIN, compared in the browser | none — downloads **all** vehicles incl. every `driver_pin`, matches client-side | `driver.html:831` (`select('*')`), match `driver.html:839-850`, mirror `index.html:3898-3919` |
| **Customer — password** | username/phone + password, compared in the browser | none — downloads **all** `settings` `usr:%` rows and `app_users` rows (plaintext passwords) then matches client-side | `index.html:5149`, compare `index.html:5206-5216` |
| **Customer — WhatsApp** | name + phone only | none — **no verification of any kind** | `submitWhatsappForm` `index.html:5081`, `submitQrVerify` `index.html:5102` |
| **Customer — Google** | Supabase Auth OAuth | ✅ real `auth.uid()` | `index.html:5304`, `onAuthStateChange` `index.html:3810`, `getSession` `index.html:3818` |

Google customers are the only correctly identified actors in the system — which is
exactly why `RLS.sql` could lock `profiles` and nothing else.

---

## 3. Current exposures, ranked

| # | Severity | Exposure |
|---|---|---|
| 1 | 🔴 | Anyone can insert/update/delete `restaurants`, `menu_items` — menu & price defacement |
| 2 | 🔴 | Anyone can insert/update/delete `orders` — cancel/reassign/steal orders; **`driver.html:1266` hard-deletes an order on reject**, and any anon client can do the same |
| 3 | 🔴 | Anyone can upsert `settings` — change business phone, delivery fees, and **overwrite any customer's password** (`usr:` rows) |
| 4 | 🔴 | All `settings` `usr:` rows (plaintext passwords) readable by the anon key; login downloads every one of them to the browser |
| 5 | 🟠 | All `vehicles.driver_pin` readable → anyone can log in as any driver |
| 6 | 🟠 | All `orders` PII readable (names, phones, addresses, coordinates) |
| 7 | 🟠 | Admin password `admin123` ships in the public bundle; the gate is a `localStorage` flag anyone can set |
| 8 | 🟡 | **WhatsApp sign-in is an identity bypass**: type any phone number, become that customer. Independent of RLS — not fixed by any policy work. |

> Note on #4: even with perfect RLS, login still needs to check a password. That
> forces either Supabase Auth or a `SECURITY DEFINER` function — the client must
> never download the password store again.

---

## 4. Why this has to be staged (the coupling)

Each table is written by more than one role, so a table can only be locked once
*every* role that writes it is authenticated.

| Table | Public read | Written by | Unlocked by |
|---|---|---|---|
| `restaurants`, `menu_items` | ✅ (browse) | admin | **Stage 1** |
| `vehicles` | ✅ (driver login needs it) | driver (GPS), admin | **Stage 2** |
| `orders` | — | customer (insert), driver (status), admin | **Stage 3** |
| `settings` | `system`/`delivery` only | customer (own profile), admin | **Stage 3** |
| `profiles` | owner-only | Google customer | ✅ done (`RLS.sql`) |

Sequencing falls out of this: admin → driver → customer. Locking `orders` or
`settings` before customers authenticate would break checkout and profile saving.

**Realtime caveat:** Supabase `postgres_changes` respects RLS. The moment a table's
SELECT policy tightens, unauthenticated subscribers stop receiving events. Each
stage must therefore land the code (with its auth session) *before* the policy SQL,
in that order, on every table it touches.

---

## 5. The stages

### Stage 1 — Admin on Supabase Auth → lock menu writes
*Smallest blast radius. Fixes the worst defacement risk. Fully independent.*

**SQL (you run in Supabase SQL Editor):**
- Create one admin auth user (email + password, or I generate SQL for it).
- Add `is_admin boolean` to `profiles`, or a small `admins(user_id uuid references auth.users(id))` table — the latter keeps `profiles` clean.
- `ENABLE ROW LEVEL SECURITY` already on; add write policies to `restaurants` and
  `menu_items` requiring `auth.uid() IS NOT NULL` + admin check. Reads stay `USING (true)`.

**Code (`admin.html`, `index.html`):**
- Replace the hardcoded check at `admin.html:1817-1833` and `index.html:4921-4934`
  with `sb.auth.signInWithPassword({ email, password })`.
- Restore the session on load with `sb.auth.getSession()` (today: `admin_auth` flag, `admin.html:2246`).
- `adLogout()` → also `sb.auth.signOut()` (`admin.html:1792`, `index.html:7507`).
- Remove `admin123` from all three files (`admin.html:1821`, `index.html:4925`, `index_original.html:4653`).

**Unlocks:** nobody can deface menu, prices, or categories.
**Does not yet fix:** driver/customer/order/settings writes (they're still anonymous).
**Risk:** low. Admin login is one function in each file; failure mode is "can't log in to admin", which is visible immediately and trivially reversible.
**Rollback:** revert the commit, `DROP POLICY`.

---

### Stage 2 — Driver on Supabase Auth → lock `vehicles`, stop leaking PINs

**SQL:**
- `ALTER TABLE vehicles ADD COLUMN auth_user_id uuid REFERENCES auth.users(id);`
- Create one auth user per driver. **To keep the driver UX unchanged**, seed the
  auth password *as the current PIN*, so drivers still type username + 4-digit PIN —
  it just becomes a real credential checked server-side.
- Drop `driver_pin` from public read (column-level `REVOKE`, or a `vehicles_public`
  view without it, or move login to a `SECURITY DEFINER` function).

**Code (`driver.html`, `index.html`):**
- Login flow stops doing `select('*')` on all vehicles (`driver.html:831`) and stops
  matching client-side (`driver.html:839-850`). Instead: `signInWithPassword` with a
  synthetic driver email (e.g. `<phone>@drivers.gopoint.app`), then load *that*
  driver's vehicle row filtered by `auth_user_id = auth.uid()`.
- `vehicles` SELECT policy → own row (`auth_user_id = auth.uid()`) for drivers,
  plus admin; public read via view for the GPS marker if customers see driver position.
- `orders` UPDATE policy → driver assigned to that order.
- Fix `driver.html:1266`: reject should **cancel**, not hard-delete. (`index.html:4334`
  already does this correctly — the two files have diverged.)
- `dpDriver` session restore: replace `localStorage['dpDriver']` (`driver.html:1645`)
  with `sb.auth.getSession()`.

**Unlocks:** driver impersonation impossible; PINs no longer public; drivers can no longer delete arbitrary orders.
**Risk:** medium. Driver login is the most-used flow on delivery days and there's no staging environment. **Do not schedule this during peak hours.**
**Rollback:** keep the old PIN path behind a flag for one release so drivers can still get in.

---

### Stage 3 — Customer passwords → Supabase Auth → lock `orders` + `settings`

*The hard one. Needs a product decision first — see §6.*

**Approach (recommended): lazy migration, no bulk backfill.**
1. Keep the existing `settings` `usr:` rows as a **legacy credential store only**.
2. Add a `SECURITY DEFINER` function `login_legacy(p_identifier, p_password) returns jsonb`
   that reads the row and compares the password **server-side**, returning profile
   fields but never the password. Lock `settings` SELECT so anon can no longer read `usr:%` rows.
   → This alone kills exposure #4 immediately, before any auth-user migration.
3. On a legacy user's next successful login: call `sb.auth.signUp()` with the
   already-verified credentials to create a real auth user, then mark the legacy row
   `migratedTo`. Subsequent logins use `signInWithPassword`.
4. Never store passwords in `localStorage` again (`gopoint_users` / `gopoint_user`).

**Why lazy rather than a bulk SQL backfill:** no single deploy flips every customer
off login at once; failures are isolated to one user; fully reversible per-account.

**Requires:** email confirmation **disabled** in Supabase Auth (dashboard setting),
because `signUp` needs an email and most customers only have a phone number.
Phone-only customers get a synthetic email (`<phone>@gopoint.customers`). See §6.2.

**Code (`index.html`):**
- `loginWithPhone` (`5179`) → `signInWithPassword`, falling back to `login_legacy`.
- `appFindRemoteUser` (`5139`) → stop downloading the whole table; profile reads go to
  `profiles` / a `user_accounts` table keyed by `user_id`, not `settings`.
- `pfResolveStoredPassword` (`5621`) → change-password verifies via
  `sb.auth.updateUser({ password })`, not by comparing a downloaded password.
- `syncUserRecord` (`5378`) / `pfSyncProfileToCloud` (`5898`) → move account data out
  of `settings` into a table with a `user_id` FK so owner-only RLS works naturally.
- `adLoadRemoteUsers` / `adPersistResetPassword` (`6956`, `7064`) → admin password
  reset becomes `sb.auth.admin.*`, which needs a **service-role key in a serverless
  function** — currently there is no server code in the repo at all.
- Lock `orders` (customer inserts own, driver assigned, admin all) and `settings`
  (owner-only account rows, admin for config).

**Unlocks:** plaintext password store gone; customer PII protected; order writes authorized.
**Risk:** highest. Touches the primary login path for the largest user group.
**Rollback:** the legacy function keeps working, so any failed `signUp` falls back to step 2.

---

### Stage 4 — WhatsApp decision, cleanup, final review

- Decide WhatsApp (§6.1) and implement.
- Remove dead code: `supaSignIn` / `supaSignUp` / `supaSignOut` (defined, never called —
  `admin.html:1096-1106`, `index.html:3349-3364`, `driver.html:667-682`), all `app_users`
  references (`admin.html:1620`, `index.html:5145`, `6960` — the table is not in `SB.sql`
  and appears not to exist), and unreachable `index.html:showAdminDashboard` (`7546`).
- Delete `index_original.html` (stale 6,600-line duplicate).
- Final pass: re-read every policy in `RLS.sql` + the new stage SQL as one coherent set.
- Consider `orders` column tightening and a `settings` read policy exposing only
  `system` / `delivery` to anon.

---

## 6. Decisions I need from you before starting

**6.1 — WhatsApp sign-in (blocking for Stage 4).** Today it verifies nothing.
Options:
- **(a) Leave as-is** — zero friction, but anyone can become any customer. Cheapest.
- **(b) Require a password on first WhatsApp login** — reuse the existing "Set Password"
  flow; afterwards they sign in normally. Free, no new infra. **(b) is my recommendation.**
- **(c) Real WhatsApp OTP** — secure, but needs the WhatsApp Business API or Twilio,
  i.e. a backend, an account, and money. Out of scope for a static site.

**6.2 — Email confirmation must be turned off** for the `signUp`-based customer
migration (dashboard → Auth → Providers → Email → "Confirm email" off), because most
customers are phone-only and get a synthetic address. Alternative: SMS OTP, which
needs Twilio. Confirm you're OK with disabling email confirmation.

**6.3 — Admin password change.** `admin123` has been in a public bundle and in git
history. Whatever we do, the credential must be changed. Confirm you want to pick a
new one (and note git history still contains the old string — say the word if you want
that scrubbed too).

**6.4 — Order reject semantics.** `driver.html:1266` permanently deletes the order;
`index.html:4334` cancels it. I'd standardize on cancel. Confirm.

**6.5 — Scope.** Do you want all four stages, or a subset? Stages 1 and 2 are
clear wins with contained risk. Stage 3 is the large one.

---

## 7. What I cannot do from here

- **Run SQL.** I hold only the publishable key — no SQL execution rights. Every stage
  has a SQL half that you run in Supabase Dashboard → SQL Editor. I'll hand you the
  exact script each time.
- **Create auth users from the client.** `signUp` works; creating an *existing* admin
  or driver as an auth user requires either the dashboard or the service-role key.
- **Test on staging.** There is only production (Vercel + live Supabase). Hence:
  code first → verify → then run the policy SQL, per stage, never in one step.
- **Guarantee realtime keeps working after a policy changes.** `postgres_changes`
  honours RLS; the session must exist before the policy drops.

---

## 8. Working rules for execution

1. Two steps per stage: **land code → verify live → run SQL**. Never together.
2. Every stage gets its own commit, its own SQL file, and an explicit rollback command.
3. Validate JS in `index.html`, `admin.html`, `driver.html` after every change
   (`D:\OpenCodeTemp\opencode\validate_js2.py <file>`).
4. No stage ships during driver peak hours.
5. Each stage is independently shippable — if Stage 3 never happens, Stages 1–2
   still leave the site materially safer than today.

---

## 9. Rough effort

| Stage | Size | Risk | Blocking decisions |
|---|---|---|---|
| 1 — Admin auth | S | Low | 6.3 |
| 2 — Driver auth | M | Medium | 6.4 |
| 3 — Customer password auth | L | High | 6.2 |
| 4 — WhatsApp + cleanup | M | Low | 6.1 |

Stages 1 and 2 are where the disproportionate value is: small, contained, and they
remove menu defacement and driver impersonation. Stage 3 is the one that eliminates
plaintext passwords, and it's genuinely a project rather than an afternoon.
