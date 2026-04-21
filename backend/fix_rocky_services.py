#!/usr/bin/env python
"""
Manual fix: Remove Rocky's incorrect Dietitian Consultation service.
This service doesn't match Rocky's profession (Electrician).
"""

import os
import sys
import django

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from supabase_config import get_supabase_client

supabase = get_supabase_client()

# Find Rocky's Dietitian Consultation service
result = supabase.table('seva_service').select(
    'id,title,provider_id,category_id,price,description'
).eq('provider_id', 25).execute()

print("Rocky's current services:")
for s in (result.data or []):
    print(f"  - ID {s['id']}: {s['title']} ({s['category_id']}) - Price: {s.get('price')}")

# Remove Dietitian Consultation services for Rocky
services_to_remove = [
    s for s in (result.data or [])
    if s.get('title', '').lower() == 'dietitian consultation'
]

print(f"\nRemoving {len(services_to_remove)} mismatched service(s)...")

for s in services_to_remove:
    try:
        supabase.table('seva_service').delete().eq('id', s['id']).execute()
        print(f"✓ Deleted: ID {s['id']}: {s['title']}")
    except Exception as e:
        print(f"✗ Error deleting ID {s['id']}: {e}")

print("\nRocky's services after cleanup:")
result = supabase.table('seva_service').select(
    'id,title,provider_id,category_id,price'
).eq('provider_id', 25).execute()

for s in (result.data or []):
    print(f"  - ID {s['id']}: {s['title']} (Price: {s.get('price')})")

print(f"\nTotal: {len(result.data or [])} services for Rocky")
