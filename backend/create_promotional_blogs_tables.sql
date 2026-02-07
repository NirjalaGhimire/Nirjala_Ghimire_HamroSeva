-- Promotional banners and blogs for Hamro Sewa.
-- Run in Supabase SQL editor.

-- Promotional banners (carousel/offers)
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

-- Blog posts
CREATE TABLE IF NOT EXISTS seva_blog (
  id SERIAL PRIMARY KEY,
  title VARCHAR(300) NOT NULL,
  body TEXT NOT NULL,
  excerpt VARCHAR(500),
  image_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample data (run once; add more via Supabase Table Editor)
INSERT INTO seva_promotional_banner (title, description, sort_order) VALUES
  ('Welcome to Hamro Sewa', 'Book trusted local services across Nepal. Services at your fingertips.', 1),
  ('Refer & Earn', 'Share your referral code and earn loyalty points when your friends book a service.', 2);

INSERT INTO seva_blog (title, body, excerpt) VALUES
  ('How to book a service on Hamro Sewa', 'Open the app, choose a category like Plumbing or Cleaning, pick a service and provider, select date and time, and confirm your booking. You can pay via eSewa or other methods.', 'Simple steps to book any service.'),
  ('Why choose local service providers?', 'Local providers know your area, offer competitive prices, and help build community trust. Hamro Sewa connects you with verified professionals across Nepal.', 'Benefits of booking local.');
