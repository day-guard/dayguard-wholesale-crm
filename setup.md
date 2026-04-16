# day-guard CRM — Supabase setup

One-time setup for Felix. ~10 minutes total.

## 1. Run the schema

1. Open the Supabase dashboard for project `wldertprtchjlllvrxya`.
2. Left sidebar → **SQL Editor** → **New query**.
3. Open `schema.sql` from this repo, copy all of it, paste into the editor.
4. Click **Run** (bottom right, or Cmd+Enter).
5. Left sidebar → **Database** → **Tables** → confirm you see 3 tables: `accounts`, `check_ins`, `purchase_orders`.

If the old `accounts` (single-blob) table existed, `schema.sql` drops it. Confirmed empty before writing this.

## 2. Configure Auth

1. **Authentication** → **Providers** → **Email**.
2. Ensure **Enable Email provider** is **on**.
3. Scroll down — **Confirm email** can stay on (OTP flow still works).
4. **Enable Email Signups** — turn **OFF**. This prevents random emails from self-registering. Only you can add users.
5. Save.

## 3. Add users

**Authentication** → **Users** → **Add user** → **Create new user**. Add these:

| Email | Auto Confirm User |
|---|---|
| `team@dayguard.com` | ✅ yes |
| (optional) `felix@dayguard.com` or your personal email | ✅ yes |

You don't set passwords — they'll sign in with one-time codes sent to the email.

## 4. Configure redirect URLs

**Authentication** → **URL Configuration**:

- **Site URL**: `https://dayguard-wholesale-crm.vercel.app`
- **Redirect URLs** (add each): 
  - `https://dayguard-wholesale-crm.vercel.app`
  - `https://dayguard-wholesale-crm.vercel.app/*`
  - `http://localhost:*` *(for local testing)*

OTP codes don't strictly require this since there's no redirect, but it's good hygiene.

## 5. Test the login

Once `index.html` is updated (next step in my plan), go to the deployed site and sign in with `team@dayguard.com`. You'll get a 6-digit code by email.

---

## Adding / removing users later

**To add someone:** Authentication → Users → Add user.

**To remove someone:** Authentication → Users → click the user → Delete. Their session dies on next page load.

**To add a new rep** (e.g. someone besides Wyatt / Kaedin / Felix): you need to update the CHECK constraint in two places in the DB — run this in SQL Editor:

```sql
ALTER TABLE public.accounts DROP CONSTRAINT accounts_rep_check;
ALTER TABLE public.accounts ADD CONSTRAINT accounts_rep_check
  CHECK (rep IN ('Wyatt','Kaedin','Felix','NewPerson'));

ALTER TABLE public.check_ins DROP CONSTRAINT check_ins_logged_by_check;
ALTER TABLE public.check_ins ADD CONSTRAINT check_ins_logged_by_check
  CHECK (logged_by IN ('Wyatt','Kaedin','Felix','NewPerson'));

ALTER TABLE public.purchase_orders DROP CONSTRAINT purchase_orders_logged_by_check;
ALTER TABLE public.purchase_orders ADD CONSTRAINT purchase_orders_logged_by_check
  CHECK (logged_by IN ('Wyatt','Kaedin','Felix','NewPerson'));
```

And add the option in `index.html` (rep dropdown + name picker list).

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
contact        text           logged_by          text    pay_method           text [check]
phone          text           created_at         ts      date_paid            date
ship_address   text                                      boxes_after_delivery int
placement      text                                      notes                text
boxes_on_shelf int                                       logged_by            text
notes          text                                      created_at           ts
date_added     date
created_at     ts
updated_at     ts  (auto)
```

All three tables are behind Row Level Security: authenticated users can read and write anything; anonymous users can't do anything.
