-- Payment transactions (eSewa, etc.) linked to bookings.
-- Run in Supabase SQL editor.
CREATE TABLE IF NOT EXISTS seva_payment (
    id SERIAL PRIMARY KEY,
    booking_id INTEGER NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    transaction_id VARCHAR(100) NOT NULL UNIQUE,
    gateway VARCHAR(50) DEFAULT 'esewa',
    status VARCHAR(20) DEFAULT 'pending',
    ref_id VARCHAR(100),
    raw_response TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_status CHECK (status IN ('pending', 'completed', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_seva_payment_booking_id ON seva_payment(booking_id);
CREATE INDEX IF NOT EXISTS idx_seva_payment_transaction_id ON seva_payment(transaction_id);
