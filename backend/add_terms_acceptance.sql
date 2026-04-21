-- Add terms and conditions acceptance tracking to users
ALTER TABLE seva_auth_user
ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP NULL;

-- Create index on terms_accepted for faster queries
CREATE INDEX IF NOT EXISTS idx_terms_accepted ON seva_auth_user(terms_accepted);
