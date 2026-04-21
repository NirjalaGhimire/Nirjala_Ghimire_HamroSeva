-- Create promotional banner table if missing, then add optional category_id.
-- Run this in Supabase SQL editor. Safe to run multiple times.

-- 1. Create table if it doesn't exist (fixes "relation seva_promotional_banner does not exist")
CREATE TABLE IF NOT EXISTS seva_promotional_banner (
  id SERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  image_url VARCHAR(500),
  link_url VARCHAR(500),
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seva_promotional_banner_active ON seva_promotional_banner(is_active);

-- 2. Add category_id for category-based banners (optional)
ALTER TABLE seva_promotional_banner
  ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES seva_servicecategory(id);

CREATE INDEX IF NOT EXISTS idx_seva_promotional_banner_category
  ON seva_promotional_banner(category_id);

COMMENT ON COLUMN seva_promotional_banner.category_id IS 'Optional: show banner only for this service category; NULL = show to all.';
