-- Add "Courier Service" for Monish (provider id 27) so he appears when customers select Courier Service under Transportation.
-- Run in Supabase SQL Editor. Category 5 = Transportation.
INSERT INTO public.seva_service (
  provider_id, category_id, title, description, price, duration_minutes, location, status
)
SELECT 27, 5, 'Courier Service', 'Package and document delivery', 200, 60, 'Kathmandu', 'active'
WHERE NOT EXISTS (
  SELECT 1 FROM public.seva_service s
  WHERE s.provider_id = 27 AND s.category_id = 5 AND s.title = 'Courier Service'
);
