-- Extend review workflow metadata and enforce one review per booking.
-- Safe to run multiple times.

ALTER TABLE seva_review
    ADD COLUMN IF NOT EXISTS service_id INTEGER REFERENCES seva_service(id),
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Backfill service_id from booking rows where missing.
UPDATE seva_review r
SET service_id = b.service_id
FROM seva_booking b
WHERE r.booking_id = b.id
  AND (r.service_id IS NULL);

-- Keep one review per booking at DB level.
CREATE UNIQUE INDEX IF NOT EXISTS ux_seva_review_booking_id
ON seva_review(booking_id);

-- Helpful indexes for provider/customer dashboard queries.
CREATE INDEX IF NOT EXISTS idx_seva_review_provider_created
ON seva_review(provider_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_seva_review_customer_created
ON seva_review(customer_id, created_at DESC);
