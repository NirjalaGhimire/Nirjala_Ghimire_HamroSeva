-- User requests to add a new service/category (sent to admins). Run in Supabase SQL editor.

CREATE TABLE IF NOT EXISTS seva_service_category_request (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  requested_title TEXT NOT NULL,
  description TEXT,
  address TEXT,
  latitude NUMERIC(10, 8),
  longitude NUMERIC(11, 8),
  image_urls TEXT,
  status VARCHAR(32) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_svc_cat_req_customer ON seva_service_category_request(customer_id);
CREATE INDEX IF NOT EXISTS idx_svc_cat_req_status ON seva_service_category_request(status);
CREATE INDEX IF NOT EXISTS idx_svc_cat_req_created ON seva_service_category_request(created_at DESC);

COMMENT ON TABLE seva_service_category_request IS 'Customers ask admins to add a new service type not yet in the app.';
