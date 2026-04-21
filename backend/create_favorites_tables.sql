-- Favorites tables for Hamro Sewa
-- Run in Supabase SQL editor.
-- Keeps provider favorites and service favorites separate.

CREATE TABLE IF NOT EXISTS seva_favorite_provider (
  id BIGSERIAL PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  provider_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_seva_favorite_provider_unique_active
  ON seva_favorite_provider(customer_id, provider_id);

CREATE INDEX IF NOT EXISTS idx_seva_favorite_provider_customer
  ON seva_favorite_provider(customer_id);

CREATE INDEX IF NOT EXISTS idx_seva_favorite_provider_provider
  ON seva_favorite_provider(provider_id);

COMMENT ON TABLE seva_favorite_provider IS 'Customer favorite providers. One row per (customer, provider).';

CREATE TABLE IF NOT EXISTS seva_favorite_service (
  id BIGSERIAL PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  service_id INTEGER NOT NULL REFERENCES seva_service(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_seva_favorite_service_unique_active
  ON seva_favorite_service(customer_id, service_id);

CREATE INDEX IF NOT EXISTS idx_seva_favorite_service_customer
  ON seva_favorite_service(customer_id);

CREATE INDEX IF NOT EXISTS idx_seva_favorite_service_service
  ON seva_favorite_service(service_id);

COMMENT ON TABLE seva_favorite_service IS 'Customer favorite services. One row per (customer, service).';
