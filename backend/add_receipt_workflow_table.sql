-- Payment receipt table for customer/provider/admin visibility.
-- Run in Supabase SQL editor.

CREATE TABLE IF NOT EXISTS seva_receipt (
  id SERIAL PRIMARY KEY,
  receipt_id VARCHAR(80) NOT NULL UNIQUE,
  booking_id INTEGER NOT NULL,
  payment_id INTEGER,
  customer_id INTEGER NOT NULL,
  provider_id INTEGER,
  service_name VARCHAR(200),
  payment_method VARCHAR(40),
  paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  service_charge DECIMAL(10,2) NOT NULL DEFAULT 0,
  final_total DECIMAL(10,2) NOT NULL DEFAULT 0,
  payment_status VARCHAR(30) NOT NULL DEFAULT 'completed',
  refund_status VARCHAR(30),
  issued_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seva_receipt_booking_id ON seva_receipt(booking_id);
CREATE INDEX IF NOT EXISTS idx_seva_receipt_customer_id ON seva_receipt(customer_id);
CREATE INDEX IF NOT EXISTS idx_seva_receipt_payment_id ON seva_receipt(payment_id);

COMMENT ON TABLE seva_receipt IS 'Stores generated payment receipts and refund updates.';
