-- Password reset flow: store codes and optional reset token.
-- Run this in your Supabase SQL editor.

CREATE TABLE IF NOT EXISTS seva_password_reset (
  id SERIAL PRIMARY KEY,
  contact_type VARCHAR(10) NOT NULL CHECK (contact_type IN ('email', 'phone')),
  contact_value VARCHAR(255) NOT NULL,
  code VARCHAR(10) NOT NULL,
  reset_token VARCHAR(64) UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_seva_password_reset_contact
  ON seva_password_reset(contact_type, contact_value);
CREATE INDEX IF NOT EXISTS idx_seva_password_reset_token
  ON seva_password_reset(reset_token) WHERE reset_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_seva_password_reset_expires
  ON seva_password_reset(expires_at);

COMMENT ON TABLE seva_password_reset IS 'Forgot password: code sent to email/phone; reset_token issued after verify; invalidate after set new password.';
