-- Referral & Loyalty: add columns to auth user and create referral table.
-- Run this in your Supabase SQL editor.

-- 1) Add referral and loyalty columns to users (if not exists)
ALTER TABLE seva_auth_user
  ADD COLUMN IF NOT EXISTS referral_code VARCHAR(50) UNIQUE,
  ADD COLUMN IF NOT EXISTS loyalty_points INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS referred_by_id INTEGER REFERENCES seva_auth_user(id);

-- 2) Create unique index for referral_code (for lookups)
CREATE UNIQUE INDEX IF NOT EXISTS idx_seva_auth_user_referral_code
  ON seva_auth_user(referral_code) WHERE referral_code IS NOT NULL;

-- 3) Referral records: who referred whom, status, points
CREATE TABLE IF NOT EXISTS seva_referral (
  id SERIAL PRIMARY KEY,
  referrer_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  referred_user_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  status VARCHAR(30) NOT NULL DEFAULT 'signed_up',
  points_referrer INTEGER NOT NULL DEFAULT 0,
  points_referred INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(referred_user_id)
);

CREATE INDEX IF NOT EXISTS idx_seva_referral_referrer ON seva_referral(referrer_id);
CREATE INDEX IF NOT EXISTS idx_seva_referral_referred ON seva_referral(referred_user_id);

COMMENT ON TABLE seva_referral IS 'Tracks referrals: referrer_id referred referred_user_id. status: signed_up, first_booking_completed. Points awarded when referred user completes first booking.';
