#!/usr/bin/env python
"""Clean up invalid services: delete services where provider's profession doesn't match category"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from supabase_config import get_supabase_client
from services.category_matching import provider_profession_matches_category

supabase = get_supabase_client()

# Fetch all services with provider and category info
response = supabase.table('seva_service').select('id,provider_id,category_id,title').execute()
services = response.data or []

# Fetch all categories for lookup
cat_response = supabase.table('seva_servicecategory').select('id,name').execute()
categories = {c['id']: c['name'] for c in (cat_response.data or [])}

# Fetch all providers for lookup
prov_response = supabase.table('seva_auth_user').select('id,username,profession').execute()
providers = {p['id']: p for p in (prov_response.data or [])}

print("🔍 Scanning all services for profession-category mismatches...\n")

invalid_services = []

for s in services:
    provider_id = s['provider_id']
    category_id = s['category_id']
    title = s['title']
    
    provider = providers.get(provider_id)
    category = categories.get(category_id)
    
    if not provider or not category:
        continue
    
    profession = (provider.get('profession') or '').strip()
    category_name = category
    
    # Check if profession matches category
    matches = provider_profession_matches_category(profession, category_name)
    
    if not matches:
        invalid_services.append({
            'id': s['id'],
            'provider_username': provider.get('username'),
            'provider_id': provider_id,
            'profession': profession,
            'service_title': title,
            'category': category_name,
        })

print(f"Found {len(invalid_services)} services with mismatched profession-category:\n")

# Group by provider
by_provider = {}
for service in invalid_services:
    provider_username = service['provider_username']
    if provider_username not in by_provider:
        by_provider[provider_username] = []
    by_provider[provider_username].append(service)

for provider_username in sorted(by_provider.keys()):
    services_list = by_provider[provider_username]
    profession = services_list[0]['profession']
    print(f"  {provider_username} (Profession: {profession})")
    for service in services_list:
        print(f"    ✗ {service['service_title']} in {service['category']} (Service ID: {service['id']})")
    print()

# Ask for deletion confirmation
if invalid_services:
    print(f"\n{'='*100}")
    print(f"Found {len(invalid_services)} invalid services.")
    print("\nThese services will be deleted because the provider's profession")
    print("does not match the service category.")
    print(f"\n{'='*100}\n")
    
    response = input("Delete these invalid services? (yes/no): ").strip().lower()
    
    if response in ('yes', 'y'):
        service_ids = [s['id'] for s in invalid_services]
        deleted_count = 0
        
        for service_id in service_ids:
            try:
                supabase.table('seva_service').delete().eq('id', service_id).execute()
                deleted_count += 1
            except Exception as e:
                print(f"Error deleting service {service_id}: {e}")
        
        print(f"\n✓ Deleted {deleted_count}/{len(invalid_services)} invalid services")
    else:
        print("❌ Deletion cancelled")
else:
    print("✓ All services have valid profession-category matching!")
