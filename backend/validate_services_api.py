#!/usr/bin/env python
"""Validate that services API returns only valid services with correct providers"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from services.views import _get_services_raw_from_supabase

print("=" * 100)
print("SERVICES API VALIDATION")
print("=" * 100)

# Test each category
from supabase_config import get_supabase_client

supabase = get_supabase_client()
categories = supabase.table('seva_servicecategory').select('id,name').order('name').execute()

total_valid = 0
total_invalid = 0

for category in categories.data:
    cat_id = category['id']
    cat_name = category['name']
    
    # Fetch services for this category
    services = _get_services_raw_from_supabase(category_id=cat_id)
    
    print(f"\n📚 {cat_name.upper()} (Category ID: {cat_id})")
    print("-" * 100)
    
    if not services:
        print("  (No services)")
    else:
        print(f"  {len(services)} services in this category:\n")
        
        # Group by provider
        by_provider = {}
        for s in services:
            provider_name = s.get('provider_name', 'Unknown')
            if provider_name not in by_provider:
                by_provider[provider_name] = []
            by_provider[provider_name].append(s)
        
        for provider_name in sorted(by_provider.keys()):
            service_list = by_provider[provider_name]
            print(f"    • {provider_name} ({len(service_list)} services)")
            for service in service_list:
                title = service.get('title', 'Unknown')
                price = service.get('price', 0)
                print(f"      - {title} (Rs. {price})")
        
        total_valid += len(services)

print("\n" + "=" * 100)
print(f"TOTAL VALID SERVICES: {total_valid}")
print("=" * 100)

# Now check: which providers have NO services?
print("\n\n📋 PROVIDERS WITH NO VALID SERVICES:")
print("-" * 100)

providers_response = supabase.table('seva_auth_user').select(
    'id,username,profession,role,is_active'
).in_('role', ['provider', 'prov', 'Provider', 'Prov']).execute()

providers_with_services = set()
for cat in categories.data:
    services = _get_services_raw_from_supabase(category_id=cat['id'])
    for s in services:
        if s.get('provider_id'):
            providers_with_services.add(int(s['provider_id']))

providers_without_services = []
for prov in providers_response.data:
    if prov['id'] not in providers_with_services:
        providers_without_services.append(prov)

if providers_without_services:
    for prov in sorted(providers_without_services, key=lambda x: x['username']):
        status = "✓ Active" if prov.get('is_active') else "✗ Inactive"
        print(f"  • {prov['username']} (Profession: {prov.get('profession')}) {status}")
else:
    print("  (All active providers have at least one valid service)")

print("\n" + "=" * 100)
