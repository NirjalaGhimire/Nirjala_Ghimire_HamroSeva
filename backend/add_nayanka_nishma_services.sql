-- =============================================================================
-- Add Nayanka (Dietitian) and Nishma (Math Tutor) to seva_service.
-- Category names in your DB are "Education" and "Healthcare" (not "Mathematics Tutoring" / "Dietitian Consultation").
-- Run the ENTIRE file in Supabase SQL Editor.
-- =============================================================================

-- Nayanka (provider_id 29) → Healthcare category, service title "Dietitian Consultation"
INSERT INTO public.seva_service (
  provider_id, category_id, title, description, price, duration_minutes, location, status
)
SELECT 29, c.id, 'Dietitian Consultation', 'Professional diet and nutrition consultation', 1500, 60, 'Kathmandu', 'active'
FROM public.seva_servicecategory c
WHERE c.name ILIKE '%healthcare%' OR c.name ILIKE '%health%'
  AND NOT EXISTS (SELECT 1 FROM public.seva_service s WHERE s.provider_id = 29 AND s.category_id = c.id)
LIMIT 1;

-- Nishma (provider_id 24) → Education / Tutoring category, service title "Mathematics Tutoring"
INSERT INTO public.seva_service (
  provider_id, category_id, title, description, price, duration_minutes, location, status
)
SELECT 24, c.id, 'Mathematics Tutoring', 'Mathematics tutoring and exam preparation', 1200, 60, 'Kathmandu', 'active'
FROM public.seva_servicecategory c
WHERE (c.name ILIKE '%education%' OR c.name ILIKE '%tutor%')
  AND NOT EXISTS (SELECT 1 FROM public.seva_service s WHERE s.provider_id = 24 AND s.category_id = c.id)
LIMIT 1;
