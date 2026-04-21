-- Add address and coordinates to seva_booking for Google Maps integration.
-- REQUIRED: Run this once in Supabase Dashboard → SQL Editor → New query, then Run.
-- If you don't run this, orders still save but without address/lat/lng (backend falls back).

ALTER TABLE seva_booking
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
  ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

COMMENT ON COLUMN seva_booking.address IS 'Full address string from Google Maps / user input';
COMMENT ON COLUMN seva_booking.latitude IS 'Latitude for map marker and directions';
COMMENT ON COLUMN seva_booking.longitude IS 'Longitude for map marker and directions';
