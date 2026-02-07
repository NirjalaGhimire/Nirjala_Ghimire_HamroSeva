-- Add 6 subcategory-style services per main category (seva_servicecategory).
-- Run once in Supabase SQL Editor. Uses existing providers (ids 15, 19, 23, 24, 25).
-- Category IDs: 1=Home Services, 2=Beauty & Wellness, 3=Education, 4=Technology,
--               5=Transportation, 6=Healthcare, 7=Events

-- Insert only when (category_id, title) does not already exist.
INSERT INTO public.seva_service (
  provider_id, category_id, title, description, price, duration_minutes, location, status
)
SELECT v.provider_id, v.category_id, v.title, v.description, v.price, v.duration_minutes, v.location, v.status
FROM (VALUES
  -- Category 1: Home Services (6)
  (15, 1, 'Plumber', 'Plumbing repairs, installations, and maintenance', 800, 60, 'Kathmandu', 'active'),
  (23, 1, 'Electrician', 'Electrical repairs, wiring, and installations', 900, 90, 'Kathmandu', 'active'),
  (15, 1, 'Home Cleaning Service', 'Deep cleaning, regular housekeeping', 600, 120, 'Kathmandu', 'active'),
  (19, 1, 'Carpenter', 'Furniture repair, custom woodwork, fittings', 750, 90, 'Patan', 'active'),
  (19, 1, 'Painter', 'Interior and exterior painting, wall finishing', 700, 120, 'Lalitpur', 'active'),
  (23, 1, 'Appliance Repair Specialist', 'Repair of home appliances and equipment', 850, 60, 'Kathmandu', 'active'),
  -- Category 2: Beauty & Wellness (6)
  (19, 2, 'Beautician', 'Skincare, makeup, and beauty treatments', 500, 60, 'Kathmandu', 'active'),
  (19, 2, 'Hair Stylist', 'Haircut, styling, coloring, and treatments', 450, 45, 'Kathmandu', 'active'),
  (23, 2, 'Spa Therapist', 'Massage, body treatments, and relaxation', 1200, 90, 'Kathmandu', 'active'),
  (24, 2, 'Fitness Trainer', 'Personal training and fitness coaching', 600, 60, 'Kathmandu', 'active'),
  (25, 2, 'Makeup Artist', 'Bridal, party, and professional makeup', 800, 90, 'Kathmandu', 'active'),
  (15, 2, 'Massage Therapist', 'Therapeutic and relaxation massage', 1000, 60, 'Patan', 'active'),
  -- Category 3: Education / Care (6)
  (24, 3, 'Nanny', 'Childcare and nanny services', 500, 480, 'Kathmandu', 'active'),
  (15, 3, 'Elderly Caretaker', 'In-home care and companionship for elderly', 600, 480, 'Kathmandu', 'active'),
  (24, 3, 'Tutor', 'Academic tutoring and exam preparation', 400, 60, 'Kathmandu', 'active'),
  (24, 3, 'Mathematics Tutoring', 'Math tuition for all levels', 450, 60, 'Online', 'active'),
  (19, 3, 'Language Tutor', 'Language learning and conversation', 350, 60, 'Kathmandu', 'active'),
  (23, 3, 'Music Teacher', 'Piano, guitar, and music lessons', 500, 60, 'Kathmandu', 'active'),
  -- Category 4: Technology (6)
  (23, 4, 'Mobile Repair', 'Smartphone and tablet repair', 400, 45, 'Kathmandu', 'active'),
  (23, 4, 'IT Support', 'Computer and network troubleshooting', 600, 60, 'Kathmandu', 'active'),
  (24, 4, 'Web Development', 'Websites and web applications', 3000, 480, 'Remote', 'active'),
  (25, 4, 'Computer Repair', 'PC and laptop repair and upgrades', 550, 60, 'Kathmandu', 'active'),
  (15, 4, 'Software Support', 'Software installation and training', 500, 60, 'Kathmandu', 'active'),
  (19, 4, 'Network Setup', 'Wi-Fi, LAN, and network setup', 800, 90, 'Kathmandu', 'active'),
  -- Category 5: Transportation (6)
  (15, 5, 'Driver', 'Personal and chauffeur driving', 800, 480, 'Kathmandu', 'active'),
  (19, 5, 'Vehicle Rental', 'Car and bike rental services', 1500, 480, 'Kathmandu', 'active'),
  (23, 5, 'Courier Service', 'Package and document delivery', 200, 60, 'Kathmandu', 'active'),
  (24, 5, 'Bike Rental', 'Motorcycle and bicycle rental', 500, 480, 'Kathmandu', 'active'),
  (25, 5, 'Truck Rental', 'Goods and moving transport', 2500, 480, 'Kathmandu', 'active'),
  (15, 5, 'Moving Service', 'House and office relocation', 3000, 480, 'Kathmandu', 'active'),
  -- Category 6: Healthcare (6)
  (15, 6, 'Home Nurse', 'Nursing care at home', 700, 120, 'Kathmandu', 'active'),
  (19, 6, 'Physiotherapist', 'Physical therapy and rehabilitation', 800, 60, 'Kathmandu', 'active'),
  (23, 6, 'Health Check-up', 'Basic health screening at home', 500, 30, 'Kathmandu', 'active'),
  (24, 6, 'First Aid Training', 'CPR and first aid courses', 1000, 120, 'Kathmandu', 'active'),
  (25, 6, 'Dietitian Consultation', 'Diet and nutrition advice', 600, 60, 'Kathmandu', 'active'),
  (15, 6, 'Yoga Instructor', 'Yoga and wellness sessions', 400, 60, 'Kathmandu', 'active'),
  -- Category 7: Events & Miscellaneous (6)
  (19, 7, 'Photographer', 'Event and portrait photography', 2500, 240, 'Kathmandu', 'active'),
  (23, 7, 'Decorator', 'Event and venue decoration', 5000, 480, 'Kathmandu', 'active'),
  (24, 7, 'DJ', 'Music and entertainment for events', 3000, 480, 'Kathmandu', 'active'),
  (25, 7, 'Event Planner', 'Full event planning and coordination', 8000, 480, 'Kathmandu', 'active'),
  (15, 7, 'Caterer', 'Food and catering for events', 4000, 480, 'Kathmandu', 'active'),
  (19, 7, 'Videographer', 'Video recording and editing', 3500, 480, 'Kathmandu', 'active')
) AS v(provider_id, category_id, title, description, price, duration_minutes, location, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.seva_service s
  WHERE s.category_id = v.category_id AND s.title = v.title
);
