-- Add referral/loyalty columns to SQLite authentication_user (for Django admin).
-- Run if migration 0002 fails (e.g. disk I/O). From backend folder:
--   sqlite3 db.sqlite3 < add_referral_columns_sqlite.sql

-- SQLite doesn't support IF NOT EXISTS for columns; ignore errors if already present.
ALTER TABLE authentication_user ADD COLUMN referral_code VARCHAR(50) NULL;
ALTER TABLE authentication_user ADD COLUMN loyalty_points INTEGER NOT NULL DEFAULT 0;
ALTER TABLE authentication_user ADD COLUMN referred_by_id INTEGER NULL;
