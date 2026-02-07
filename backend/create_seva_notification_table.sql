-- Customer notifications (e.g. "Booking declined by provider")
-- Run this in your Supabase SQL editor if you use Supabase.
CREATE TABLE IF NOT EXISTS seva_notification (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT,
    booking_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seva_notification_user_id ON seva_notification(user_id);
