# day-guard CRM — Supabase setup

One-time setup for Felix. ~10 minutes total. This is what's already been done for the current project (`wldertprtchjlllvrxya`) — keep as reference if you ever need to rebuild from scratch.

## 1. Run the schema

1. Open the Supabase dashboard for the project.
2. Left sidebar → **SQL Editor** → **New query**.
3. Open `schema.sql` from this repo, copy all of it, paste into the editor.
4. Click **Run** (bottom right, or Cmd+Enter).
5. Left sidebar → **Database** → **Tables** → confirm you see 3 tables: `accounts`, `check_ins`, `purchase_orders`.

## 2. Configure Auth

1. **Authentication** → **Providers** → **Email**.
2. Ensure **Enable Email provider** is **on**.
3. **Enable Email Signups** — turn **OFF**. This prevents anyone who knows the URL from creating a new account.
4. Save.

## 3. Add the team user

**Authentication** → **Users** → **Add user** → **Create new user**.

| Email | Password | Auto Confirm User |
|---|---|---|
| `team@dayguard.com` | `Teamdayguard26` | ✅ yes |

This is the single shared account Wyatt, Kaedin, and Felix all use. Both the email and the password are the team's shared credentials — exactly like the old CRM flow, but now backed by real Supabase auth so Row Level Security actually protects the database.

## 4. Configure redirect URLs

**Authentication** → **URL Configuration**:

- **Site URL**: `https://dayguard-wholesale-crm.vercel.app`
- **Redirect URLs**:
  - `https://dayguard-wholesale-crm.vercel.app/**`
  - `http://localhost:**` *(for local testing)*

## 5. Test the login

On the deployed site, enter the team password. You should land on the main CRM screen. Session persists for 30 days by default.

---

## Changing the team password later

If someone leaves the team, rotate the password so their saved session on their old device can be killed.

**Easiest path: from inside the app.**

1. Sign in on a trusted device.
2. Open browser devtools → Console, paste:
   ```js
   await sb.auth.updateUser({ password: 'NewPasswordHere' })
   ```
3. Tell the team the new password. Their existing sessions stay valid until they sign out, but the old password won't work for new sign-ins.

**Alternative: via Supabase dashboard.**

Authentication → Users → click the `team@dayguard.com` row → "Send password recovery email" (this sends a recovery link to `team@dayguard.com` — whoever has access to that inbox can set a new one).

## Adding / removing rep names

The `rep` field on each account is constrained to `Wyatt`, `Kaedin`, `Felix`. To add a new rep name (e.g., a new hire), run this in SQL Editor:

```sql
ALTER TABLE public.accounts DROP CONSTRAINT accounts_rep_check;
ALTER TABLE public.accounts ADD CONSTRAINT accounts_rep_check
  CHECK (rep IN ('Wyatt','Kaedin','Felix','NewPerson'));
```

And add the option in `index.html` (rep dropdown in the Add Account form).

## The schema at a glance

```
accounts                      check_ins                  purchase_orders
─────────                     ─────────                  ───────────────
id             uuid  PK       id                 uuid PK id                   uuid PK
name           text           account_id  → accounts     account_id    → accounts
type           text [check]   date               date    cartons              int
status         text [check]   method             text    boxes                computed: cartons*20
region         text [check]   units_remaining    int     date_confirmed       date
rep            text [check]   placement          text    ship_address         text
street/city/   text           status_at_checkin  text    invoice_sent_date    date
  state/zip                   notes              text    pay_status           text [check]
contact        text           created_at         ts      pay_method           text [check]
phone          text                                      date_paid            date
ship_address   text                                      boxes_after_delivery int
placement      text                                      notes                text
boxes_on_shelf int                                       created_at           ts
notes          text
date_added     date
created_at     ts
updated_at     ts  (auto)
```

All three tables are behind Row Level Security: authenticated users read/write everything, anonymous requests get rejected. The publishable Supabase key lives in `index.html` (safe — it's designed for client-side use). The team password is what actually gates access.
