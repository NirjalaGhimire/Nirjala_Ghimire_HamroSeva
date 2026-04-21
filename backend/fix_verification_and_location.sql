-- SQL Script to Fix Verification Status and Location Data Issues
-- Run this in your Supabase console to clean up existing data

-- 1. FIX VERIFICATION_STATUS: Set to 'unverified' if NULL
UPDATE seva_auth_user 
SET verification_status = 'unverified'
WHERE verification_status IS NULL 
  OR verification_status = '';
  
-- 2. NORMALIZE verification_status values (handle common misspellings/aliases)
-- pending_verification -> pending
UPDATE seva_auth_user 
SET verification_status = 'pending'
WHERE verification_status LIKE 'pending%';

-- verified -> approved  
UPDATE seva_auth_user 
SET verification_status = 'approved'
WHERE verification_status = 'verified';

-- on_hold / under_review -> pending
UPDATE seva_auth_user 
SET verification_status = 'pending'
WHERE verification_status IN ('on_hold', 'under_review');

-- 3. ONLY KEEP VALID STATUS VALUES
-- Any other value should be 'unverified'
UPDATE seva_auth_user 
SET verification_status = 'unverified'
WHERE verification_status NOT IN ('approved', 'pending', 'rejected', 'unverified');

-- 3b. SYNC provider verification from verification docs (SOURCE OF TRUTH)
-- Effective status priority: approved/verified > pending* > rejected > unverified
WITH doc_rollup AS (
  SELECT
    provider_id,
    CASE
      WHEN bool_or(lower(trim(status)) IN ('approved', 'verified')) THEN 'approved'
      WHEN bool_or(lower(trim(status)) LIKE 'pending%' OR lower(trim(status)) IN ('under_review', 'on_hold')) THEN 'pending'
      WHEN bool_or(lower(trim(status)) = 'rejected') THEN 'rejected'
      ELSE 'unverified'
    END AS effective_status
  FROM seva_provider_verification
  GROUP BY provider_id
)
UPDATE seva_auth_user u
SET
  verification_status = d.effective_status,
  is_verified = (d.effective_status = 'approved'),
  is_active_provider = (d.effective_status = 'approved')
FROM doc_rollup d
WHERE u.id = d.provider_id
  AND u.role IN ('provider', 'prov');

-- 3c. Providers with NO docs must be unverified
UPDATE seva_auth_user u
SET
  verification_status = 'unverified',
  is_verified = FALSE,
  is_active_provider = FALSE
WHERE u.role IN ('provider', 'prov')
  AND NOT EXISTS (
    SELECT 1
    FROM seva_provider_verification v
    WHERE v.provider_id = u.id
  );

-- 3d. Ensure customers/admins are never treated as verified/active providers
UPDATE seva_auth_user
SET
  verification_status = 'unverified',
  is_verified = FALSE,
  is_active_provider = FALSE
WHERE role NOT IN ('provider', 'prov') OR role IS NULL;

-- 4. AUDIT: View providers with missing location data (should be remedied)
SELECT 
  id,
  username,
  email,
  role,
  verification_status,
  district,
  city,
  profession
FROM seva_auth_user
WHERE role IN ('provider', 'prov')
  AND (district IS NULL OR district = '' OR city IS NULL OR city = '')
ORDER BY verification_status DESC, username;

-- 5. AUDIT: Count of providers by verification status
SELECT 
  verification_status,
  COUNT(*) as provider_count,
  COUNT(CASE WHEN (district IS NULL OR district = '') THEN 1 END) as missing_district,
  COUNT(CASE WHEN (city IS NULL OR city = '') THEN 1 END) as missing_city
FROM seva_auth_user
WHERE role IN ('provider', 'prov')
GROUP BY verification_status
ORDER BY provider_count DESC;

-- 6. AUDIT: Verified providers with complete location data
SELECT 
  id,
  username,
  profession,
  district,
  city,
  verification_status
FROM seva_auth_user
WHERE role IN ('provider', 'prov')
  AND verification_status = 'approved'
  AND district IS NOT NULL AND district != ''
  AND city IS NOT NULL AND city != ''
ORDER BY username;

-- 7. FLAG ISSUE: Show providers appearing as verified but with wrong status
SELECT 
  id,
  username,
  email,
  verification_status
FROM seva_auth_user
WHERE role IN ('provider', 'prov')
  AND (verification_status IS NULL OR verification_status NOT IN ('approved', 'pending', 'rejected', 'unverified'))
ORDER BY username;
