-- Prevent accidental duplicate service rows for the same provider + category + title.
-- Run AFTER cleaning duplicate rows in seva_service (keep one row per group), or this may fail.

-- Case-sensitive uniqueness (normalize titles in app when inserting).
CREATE UNIQUE INDEX IF NOT EXISTS idx_seva_service_provider_category_title
  ON seva_service (provider_id, category_id, title);
