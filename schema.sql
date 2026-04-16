-- =====================================================
-- day-guard retail CRM — database schema v2
-- =====================================================
-- Run this in Supabase → SQL Editor → New query → Run.
-- Idempotent: safe to run multiple times. Drops and recreates tables.
-- =====================================================

DROP TABLE IF EXISTS public.purchase_orders CASCADE;
DROP TABLE IF EXISTS public.check_ins       CASCADE;
DROP TABLE IF EXISTS public.accounts        CASCADE;

-- =====================================================
-- accounts
-- =====================================================
CREATE TABLE public.accounts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  type           TEXT NOT NULL DEFAULT 'Bar'
                 CHECK (type IN ('Bar','Liquor store','Convenience','Grocery','Restaurant','Wholesale','Other')),
  status         TEXT NOT NULL DEFAULT 'Pre-trial'
                 CHECK (status IN ('Pre-trial','Trial','Active','Dead')),
  rep            TEXT NOT NULL DEFAULT 'Wyatt'
                 CHECK (rep IN ('Wyatt','Kaedin','Felix')),
  street         TEXT,
  city           TEXT,
  state          TEXT,
  zip            TEXT,
  contact        TEXT,
  phone          TEXT,
  boxes_on_shelf INT NOT NULL DEFAULT 0 CHECK (boxes_on_shelf >= 0),
  notes          TEXT,
  date_added     DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX accounts_status_idx     ON public.accounts(status);
CREATE INDEX accounts_rep_idx        ON public.accounts(rep);
CREATE INDEX accounts_updated_at_idx ON public.accounts(updated_at DESC);

-- =====================================================
-- check_ins
-- =====================================================
CREATE TABLE public.check_ins (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id        UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  date              DATE NOT NULL DEFAULT CURRENT_DATE,
  method            TEXT NOT NULL DEFAULT 'Phone call'
                    CHECK (method IN ('Phone call','In person','Text','Email')),
  units_remaining   INT CHECK (units_remaining IS NULL OR units_remaining >= 0),
  -- Note: column is named `units_remaining` for historical reasons.
  -- Semantically this is "boxes remaining on shelf" in the current app.
  status_at_checkin TEXT
                    CHECK (status_at_checkin IN ('Pre-trial','Trial','Active','Dead')),
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX check_ins_account_idx ON public.check_ins(account_id, date DESC);
CREATE INDEX check_ins_date_idx    ON public.check_ins(date DESC);

-- =====================================================
-- purchase_orders
-- =====================================================
CREATE TABLE public.purchase_orders (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id           UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  -- A PO is created as the result of a check-in with outcome "Yes to PO".
  -- When the originating check-in is deleted (rolled back), the PO goes
  -- with it via ON DELETE CASCADE.
  check_in_id          UUID REFERENCES public.check_ins(id) ON DELETE CASCADE,
  cartons              INT  NOT NULL CHECK (cartons > 0),
  boxes                INT  GENERATED ALWAYS AS (cartons * 20) STORED,
  date_confirmed       DATE NOT NULL DEFAULT CURRENT_DATE,
  invoice_sent_date    DATE,
  pay_status           TEXT NOT NULL DEFAULT 'outstanding'
                       CHECK (pay_status IN ('outstanding','paid')),
  pay_method           TEXT
                       CHECK (pay_method IN ('Venmo','Zelle','ACH')),
  date_paid            DATE,
  boxes_after_delivery INT CHECK (boxes_after_delivery IS NULL OR boxes_after_delivery >= 0),
  notes                TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT paid_has_method_and_date CHECK (
    pay_status = 'outstanding' OR (pay_method IS NOT NULL AND date_paid IS NOT NULL)
  )
);

CREATE INDEX pos_account_idx      ON public.purchase_orders(account_id, date_confirmed DESC);
CREATE INDEX pos_pay_status_idx   ON public.purchase_orders(pay_status);
CREATE INDEX pos_check_in_idx     ON public.purchase_orders(check_in_id);
CREATE INDEX pos_invoice_sent_idx ON public.purchase_orders(invoice_sent_date)
                                  WHERE invoice_sent_date IS NOT NULL;

-- =====================================================
-- trigger: auto-update accounts.updated_at on any change
-- =====================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS accounts_set_updated_at ON public.accounts;
CREATE TRIGGER accounts_set_updated_at
  BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =====================================================
-- Row Level Security
-- =====================================================
ALTER TABLE public.accounts        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_ins       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth can read accounts"   ON public.accounts;
DROP POLICY IF EXISTS "auth can write accounts"  ON public.accounts;
CREATE POLICY "auth can read accounts"  ON public.accounts FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth can write accounts" ON public.accounts FOR ALL    TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth can read check_ins"  ON public.check_ins;
DROP POLICY IF EXISTS "auth can write check_ins" ON public.check_ins;
CREATE POLICY "auth can read check_ins"  ON public.check_ins FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth can write check_ins" ON public.check_ins FOR ALL    TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth can read pos"  ON public.purchase_orders;
DROP POLICY IF EXISTS "auth can write pos" ON public.purchase_orders;
CREATE POLICY "auth can read pos"  ON public.purchase_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth can write pos" ON public.purchase_orders FOR ALL    TO authenticated USING (true) WITH CHECK (true);
