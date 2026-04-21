-- Email verification schema for verification-first registration flow.
-- Run this in Supabase SQL editor before deploying the API changes.

ALTER TABLE seva_auth_user
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- Keep existing users able to log in after migration.
UPDATE seva_auth_user
SET email_verified = TRUE
WHERE email_verified IS DISTINCT FROM TRUE;

CREATE INDEX IF NOT EXISTS idx_seva_auth_user_email_verified
  ON seva_auth_user(email_verified);

CREATE TABLE IF NOT EXISTS seva_email_verification (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'provider')),
  code_hash VARCHAR(128),
  registration_payload JSONB,
  verification_status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'verified', 'expired', 'failed')),
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  verify_attempts INTEGER NOT NULL DEFAULT 0,
  send_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_sent_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ
);

-- Prevent duplicate unverified rows for the same email+role.
CREATE UNIQUE INDEX IF NOT EXISTS uq_seva_email_verification_pending
  ON seva_email_verification(email, role)
  WHERE is_verified = FALSE;

CREATE INDEX IF NOT EXISTS idx_seva_email_verification_lookup
  ON seva_email_verification(email, role, verification_status);

CREATE INDEX IF NOT EXISTS idx_seva_email_verification_expiry
  ON seva_email_verification(expires_at);

COMMENT ON TABLE seva_email_verification IS 'Temporary registration OTP records. Accounts are created only after OTP verification.';
COMMENT ON COLUMN seva_email_verification.code_hash IS 'HMAC-SHA256(email|otp) hash. Plain OTP is never stored.';
COMMENT ON COLUMN seva_email_verification.registration_payload IS 'Pending signup payload (includes password hash and role-specific fields).';
