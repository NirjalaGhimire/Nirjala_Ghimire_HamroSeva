-- Quote workflow + optional request image URL on bookings.
-- Run in Supabase SQL editor.

ALTER TABLE seva_booking
  ADD COLUMN IF NOT EXISTS quoted_price DECIMAL(10,2);

ALTER TABLE seva_booking
  ADD COLUMN IF NOT EXISTS request_image_url TEXT;

COMMENT ON COLUMN seva_booking.quoted_price IS 'Provider-set price after reviewing the request (status may be quoted)';
COMMENT ON COLUMN seva_booking.request_image_url IS 'Optional image URL for customer request details';

-- Widen status for quoted / rejected (stored as plain text in app)
-- No ALTER needed if status is VARCHAR(20); extend in app to: pending, quoted, confirmed, cancelled, completed, rejected
