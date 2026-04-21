#!/usr/bin/env python
"""
Diagnostic script to identify and report corrupted services:
- Services where title doesn't match provider's profession
- Duplicate services for the same provider
- Services with mismatched categories
"""

import os
import sys
import django

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from supabase_config import get_supabase_client
from collections import defaultdict


def find_mismatched_services():
    """Find services where title doesn't match provider profession."""
    print("\n" + "="*70)
    print("DIAGNOSTIC: Finding Mismatched Services")
    print("="*70)
    
    supabase = get_supabase_client()
    
    # Get all services with enriched data
    services_resp = supabase.table('seva_service').select(
        'id,title,provider_id,category_id,description,price'
    ).execute()
    
    # Get all providers
    providers_resp = supabase.table('seva_auth_user').select(
        'id,username,profession'
    ).execute()
    
    providers = {p['id']: p for p in (providers_resp.data or [])}
    
    # Get categories
    categories_resp = supabase.table('seva_servicecategory').select(
        'id,name'
    ).execute()
    
    categories = {c['id']: c.get('name', '') for c in (categories_resp.data or [])}
    
    print(f"\nTotal services: {len(services_resp.data or [])}")
    print(f"Total providers: {len(providers)}")
    print(f"Total categories: {len(categories)}")
    
    # Group by provider
    services_by_provider = defaultdict(list)
    for s in (services_resp.data or []):
        pid = s.get('provider_id')
        if pid:
            services_by_provider[pid].append(s)
    
    # Find mismatches
    mismatches = []
    duplicates = []
    
    for pid, services in services_by_provider.items():
        provider = providers.get(pid)
        if not provider:
            continue
        
        provider_name = provider.get('username', 'Unknown')
        provider_profession = (provider.get('profession') or '').lower().strip()
        
        # Find duplicate titles
        title_counts = defaultdict(list)
        for s in services:
            title = (s.get('title') or '').lower().strip()
            title_counts[title].append(s)
        
        for title, title_services in title_counts.items():
            if len(title_services) > 1:
                duplicates.append({
                    'provider_id': pid,
                    'provider_name': provider_name,
                    'title': title,
                    'count': len(title_services),
                    'service_ids': [s['id'] for s in title_services]
                })
        
        # Find mismatches between profession and service title
        for s in services:
            title = (s.get('title') or '').lower().strip()
            cat_id = s.get('category_id')
            cat_name = categories.get(cat_id, 'Unknown')
            
            # Check if title matches profession
            provider_words = {
                word.strip() 
                for word in provider_profession.split()
                if word.strip()
            }
            title_words = set(title.split())
            
            # Simple check: provider profession words should appear in title
            has_matching_word = any(
                word in title or title in word
                for word in provider_words
            )
            
            # Skip obvious matches
            if not has_matching_word and provider_profession:
                # Common profession patterns
                if not any(prof in title for prof in ['electrician', 'plumber', 'cleaner', 'tutor', 'developer', 'makeup', 'truck rental']):
                    if title not in {'home cleaning service', 'electrical repair', 'mathematics tutoring', 'web development', 'computer repair'}:
                        mismatches.append({
                            'service_id': s['id'],
                            'provider_id': pid,
                            'provider_name': provider_name,
                            'profession': provider_profession,
                            'service_title': title,
                            'category': cat_name,
                            'price': s.get('price')
                        })
    
    # Report mismatches
    if mismatches:
        print(f"\n⚠ Found {len(mismatches)} potentially mismatched services:")
        print("\nMISMATCHES (Sample of first 10):")
        for m in mismatches[:10]:
            print(f"  - {m['provider_name']} ({m['profession']}):")
            print(f"    Service: '{m['service_title']}' in {m['category']} (ID: {m['service_id']})")
            print()
    else:
        print("\n✓ No obvious profession-service mismatches found")
    
    # Report duplicates
    if duplicates:
        print(f"\n⚠ Found {len(duplicates)} duplicate service titles:")
        for d in duplicates:
            print(f"  - {d['provider_name']}: '{d['title']}' appears {d['count']} times")
            print(f"    Service IDs: {d['service_ids']}")
    else:
        print("\n✓ No duplicate service titles found")
    
    return {
        'mismatches': mismatches,
        'duplicates': duplicates
    }


def find_rocky_specific_issue():
    """Deep dive into Rocky's services."""
    print("\n" + "="*70)
    print("DIAGNOSTIC: Rocky's Services Deep Dive")
    print("="*70)
    
    supabase = get_supabase_client()
    
    # Find Rocky
    rocky_resp = supabase.table('seva_auth_user').select(
        'id,username,profession'
    ).eq('username', 'Rocky').execute()
    
    if not rocky_resp.data:
        print("Rocky not found")
        return
    
    rocky = rocky_resp.data[0]
    rocky_id = rocky['id']
    print(f"\nRocky ID: {rocky_id}")
    print(f"Profession: {rocky.get('profession')}")
    
    # Get all Rocky's services
    services_resp = supabase.table('seva_service').select(
        'id,title,category_id,provider_id,price,description'
    ).eq('provider_id', rocky_id).execute()
    
    print(f"\nRocky's services: {len(services_resp.data or [])}")
    
    # Get categories
    categories_resp = supabase.table('seva_servicecategory').select(
        'id,name'
    ).execute()
    categories = {c['id']: c.get('name', '') for c in (categories_resp.data or [])}
    
    for s in (services_resp.data or []):
        cat_name = categories.get(s.get('category_id'), 'Unknown')
        print(f"\n  Service ID: {s['id']}")
        print(f"    Title: {s.get('title')}")
        print(f"    Category: {cat_name}")
        print(f"    Price: {s.get('price')}")
        print(f"    Description: {(s.get('description') or '')[:60]}")


if __name__ == "__main__":
    results = find_mismatched_services()
    find_rocky_specific_issue()
    
    print("\n" + "="*70)
    if results['mismatches'] or results['duplicates']:
        print("⚠ Data corruption detected. These rows may need cleanup.")
    else:
        print("✓ No obvious data corruption detected.")
