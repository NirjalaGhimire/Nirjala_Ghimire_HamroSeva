-- Refund workflow migration for Supabase.
-- Run in Supabase SQL editor.

-- 1) Extend seva_payment statuses + refund metadata.
ALTER TABLE seva_payment
  ADD COLUMN IF NOT EXISTS refund_amount DECIMAL(10,2),
  ADD COLUMN IF NOT EXISTS refund_reason TEXT,
  ADD COLUMN IF NOT EXISTS refund_reference VARCHAR(100);

-- Replace old status check constraint (if it exists) with expanded values.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_name = 'seva_payment'
      AND constraint_name = 'chk_payment_status'
  ) THEN
    ALTER TABLE seva_payment DROP CONSTRAINT chk_payment_status;
  END IF;
END$$;

ALTER TABLE seva_payment
  ADD CONSTRAINT chk_payment_status CHECK (
    status IN ('pending', 'completed', 'failed', 'refund_pending', 'refunded', 'refund_rejected')
  );

-- 2) Refund request/review table.
CREATE TABLE IF NOT EXISTS seva_refund (
  id SERIAL PRIMARY KEY,
  booking_id INTEGER NOT NULL,
  payment_id INTEGER,
  customer_id INTEGER NOT NULL,
  provider_id INTEGER,
  amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'refund_pending',
  refund_reason TEXT,
  system_note TEXT,
  admin_note TEXT,
  refund_reference VARCHAR(100),
  requested_by VARCHAR(20), -- customer/provider/system
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  reviewed_by INTEGER,
  reviewed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE seva_refund
  DROP CONSTRAINT IF EXISTS chk_refund_status;
ALTER TABLE seva_refund
  ADD CONSTRAINT chk_refund_status CHECK (
    status IN (
      'refund_pending',
      'refund_provider_approved',
      'refund_provider_rejected',
      'refunded',
      'refund_rejected'
    )
  );

CREATE INDEX IF NOT EXISTS idx_seva_refund_booking_id ON seva_refund(booking_id);
CREATE INDEX IF NOT EXISTS idx_seva_refund_payment_id ON seva_refund(payment_id);
CREATE INDEX IF NOT EXISTS idx_seva_refund_customer_id ON seva_refund(customer_id);
CREATE INDEX IF NOT EXISTS idx_seva_refund_provider_id ON seva_refund(provider_id);

COMMENT ON TABLE seva_refund IS 'Tracks cancellation-triggered refund workflow and admin decisions.';

-- 3) Optional booking status expansion (if your DB has a status check constraint).
-- No-op when constraint does not exist.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_name = 'seva_booking'
      AND constraint_name = 'chk_booking_status'
  ) THEN
    ALTER TABLE seva_booking DROP CONSTRAINT chk_booking_status;
    ALTER TABLE seva_booking ADD CONSTRAINT chk_booking_status CHECK (
      status IN (
        'pending',
        'quoted',
        'awaiting_payment',
        'paid',
        'cancel_req',
        'cancelled',
        'refund_pending',
        'refund_p_approved',
        'refund_p_rejected',
        'refunded',
        'refund_rejected',
        'completed',
        'rejected',
        'confirmed',
        'accepted'
      )
    );
  END IF;
END$$;
