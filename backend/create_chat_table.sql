-- Chat messages between customer and provider, per booking.
-- Run this in Supabase SQL Editor to fix "Could not find the table 'public.seva_chat_message'".

CREATE TABLE IF NOT EXISTS seva_chat_message (
  id SERIAL PRIMARY KEY,
  booking_id INTEGER NOT NULL REFERENCES seva_booking(id) ON DELETE CASCADE,
  sender_id INTEGER NOT NULL REFERENCES seva_auth_user(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seva_chat_message_booking_id ON seva_chat_message(booking_id);
CREATE INDEX IF NOT EXISTS idx_seva_chat_message_created_at ON seva_chat_message(created_at);

COMMENT ON TABLE seva_chat_message IS 'Chat messages between customer and provider for each booking. One thread per booking.';
