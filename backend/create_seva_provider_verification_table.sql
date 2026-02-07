-- Provider identity verification documents (for Verify Your Id).
-- Run in Supabase SQL editor. References seva_auth_user(id) for provider_id.
CREATE TABLE IF NOT EXISTS seva_provider_verification (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL,
    document_type VARCHAR(50) NOT NULL,
    document_number VARCHAR(100),
    document_url VARCHAR(500),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_document_type CHECK (document_type IN (
        'work_licence',
        'passport',
        'citizenship_card',
        'national_id'
    )),
    CONSTRAINT chk_status CHECK (status IN ('pending', 'verified', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_seva_provider_verification_provider_id
    ON seva_provider_verification(provider_id);

COMMENT ON TABLE seva_provider_verification IS 'Service provider ID verification: work licence, passport, citizenship card, national ID';
