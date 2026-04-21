-- Provider identity verification documents (for Verify Your Id).
-- Run in Supabase SQL editor. References seva_auth_user(id) for provider_id.
ALTER TABLE seva_auth_user
    ADD COLUMN IF NOT EXISTS verification_status VARCHAR(30) DEFAULT 'unverified',
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS is_active_provider BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS reviewed_by INTEGER;

UPDATE seva_auth_user
SET verification_status = CASE
    WHEN role IN ('provider', 'prov') THEN COALESCE(verification_status, 'unverified')
    ELSE COALESCE(verification_status, 'approved')
END,
is_active_provider = CASE
    WHEN role IN ('provider', 'prov') AND verification_status = 'approved' THEN TRUE
    WHEN role IN ('provider', 'prov') THEN FALSE
    ELSE TRUE
END
WHERE verification_status IS NULL OR is_active_provider IS NULL;

CREATE TABLE IF NOT EXISTS seva_provider_verification (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL,
    document_type VARCHAR(60) NOT NULL,
    document_number VARCHAR(100),
    document_url VARCHAR(500),
    status VARCHAR(30) DEFAULT 'pending_verification',
    upload_status VARCHAR(30) DEFAULT 'uploaded',
    review_note TEXT,
    reviewed_by INTEGER,
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_document_type CHECK (document_type IN (
        'work_licence',
        'passport',
        'citizenship_card',
        'national_id',
        'service_certificate',
        'additional_document',
        'shop_license',
        'business_registration',
        'tax_certificate',
        'shop_photo'
    )),
    CONSTRAINT chk_status CHECK (status IN (
        'pending_verification',
        'under_review',
        'approved',
        'rejected',
        'on_hold'
    ))
);

CREATE INDEX IF NOT EXISTS idx_seva_provider_verification_provider_id
    ON seva_provider_verification(provider_id);

COMMENT ON TABLE seva_provider_verification IS 'Service provider ID verification: work licence, passport, citizenship card, national ID, plus shop documents (license, registration, tax, photo)';
