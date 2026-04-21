-- Run in Supabase SQL editor. Adds hashed OTP + attempt tracking.
-- Plaintext `code` is deprecated; new rows use `code_hash` only.

ALTER TABLE seva_password_reset
  ALTER COLUMN code DROP NOT NULL;

ALTER TABLE seva_password_reset
  ADD COLUMN IF NOT EXISTS code_hash VARCHAR(128);

ALTER TABLE seva_password_reset
  ADD COLUMN IF NOT EXISTS verify_attempts INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN seva_password_reset.code_hash IS 'HMAC-SHA256 of contact|otp; plaintext code column deprecated';
COMMENT ON COLUMN seva_password_reset.verify_attempts IS 'Failed OTP submissions; locks after threshold';
