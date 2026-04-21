#!/usr/bin/env python
"""Debug script: what services does Monishna actually have in the database?"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from supabase_config import get_supabase_client
from authentication.models import User

# Find Monishna
try:
    monishna = User.objects.get_by_username_ignore_case('monishna')
    print(f"✓ Found Monishna: ID={monishna.id}, Profession={monishna.profession}, Role={monishna.role}")
except Exception as e:
    print(f"✗ Monishna not found: {e}")
    sys.exit(1)

# Get all services for Monishna from Supabase
supabase = get_supabase_client()
response = supabase.table('seva_service').select(
    'id,provider_id,category_id,title,price,description,location'
).eq('provider_id', monishna.id).order('category_id').execute()

print(f"\n📋 All {len(response.data)} services for Monishna (ID={monishna.id}):")
print("-" * 100)

if response.data:
    for s in response.data:
        # Get category name
        cat_response = supabase.table('seva_servicecategory').select('name').eq('id', s['category_id']).execute()
        cat_name = cat_response.data[0]['name'] if cat_response.data else f"Unknown (ID={s['category_id']})"
        
        print(f"  Service ID {s['id']}")
        print(f"    Title: {s['title']}")
        print(f"    Category: {cat_name} (ID={s['category_id']})")
        print(f"    Price: Rs. {s['price']}")
        print(f"    Location: {s['location']}")
        print()
else:
    print("  (No services found)")

# Now check which categories Monishna's profession matches
print("\n🔍 Checking category matching for profession '{}':\n".format(monishna.profession))

from services.category_matching import provider_profession_matches_category

cat_response = supabase.table('seva_servicecategory').select('id,name').order('name').execute()
for cat in cat_response.data:
    matches = provider_profession_matches_category(monishna.profession, cat['name'])
    status = "✓ MATCHES" if matches else "✗ does not match"
    print(f"  {status}: {cat['name']}")

print("\n" + "="*100)
