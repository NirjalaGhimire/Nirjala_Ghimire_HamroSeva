-- Add location fields for customers and providers (stored on seva_auth_user).
-- Run this in Supabase SQL editor (or psql) after backup.

ALTER TABLE seva_auth_user
  ADD COLUMN IF NOT EXISTS district TEXT;

ALTER TABLE seva_auth_user
  ADD COLUMN IF NOT EXISTS city TEXT;

COMMENT ON COLUMN seva_auth_user.district IS 'User or provider home/service area: district (free text)';
COMMENT ON COLUMN seva_auth_user.city IS 'User or provider home/service area: city (free text)';
