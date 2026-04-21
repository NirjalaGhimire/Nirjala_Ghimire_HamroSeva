-- Run in Supabase SQL editor: auth-user profile columns used by app profile flows.
-- `qualification` is provider-specific; `profile_image_url` is used by profile UIs.
ALTER TABLE seva_auth_user
  ADD COLUMN IF NOT EXISTS qualification TEXT;
ALTER TABLE seva_auth_user
  ADD COLUMN IF NOT EXISTS profile_image_url TEXT;

COMMENT ON COLUMN seva_auth_user.qualification IS 'Provider education/credentials (free text)';
COMMENT ON COLUMN seva_auth_user.profile_image_url IS 'Signed or public URL to profile photo (set by app after upload)';
