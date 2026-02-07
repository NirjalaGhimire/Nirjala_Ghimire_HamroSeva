-- Add a bookable Electrician service for Radha (provider id 23) so Nisha can book an electrician.
-- Run this in Supabase SQL Editor if Radha does not yet appear when booking "Electrician".
-- Uses the category named "Electrical" (or any category with "electric" in the name).
-- Safe to run multiple times: only inserts when no service for provider 23 in that category exists.

WITH elec_cat AS (
  SELECT id FROM public.seva_servicecategory WHERE name ILIKE '%electric%' LIMIT 1
)
INSERT INTO public.seva_service (
  provider_id, category_id, title, description, price, duration_minutes, location, status
)
SELECT 23, elec_cat.id, 'Electrician Service', 'Expert electrical repairs and installations',
       800, 90, 'Kathmandu', 'active'
FROM elec_cat
WHERE NOT EXISTS (
  SELECT 1 FROM public.seva_service s WHERE s.provider_id = 23 AND s.category_id = elec_cat.id
);
