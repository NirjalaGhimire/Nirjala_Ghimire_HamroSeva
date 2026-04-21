#!/usr/bin/env python
"""
Cleanup script to fix corrupted services in the database.
This removes or fixes services that don't match the provider's profession.

Specifically targets:
1. Services from deleted accounts
2. Duplicate services with 0.0 price and empty description
3. Services from non-provider accounts  
4. Services with obviously mismatched titles (optional - marked for manual review)
"""

import os
import sys
import django

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from supabase_config import get_supabase_client
from services.views import _is_deleted_user, _is_valid_service_row


def cleanup_deleted_account_services():
    """Remove services from deleted accounts."""
    print("\n" + "="*70)
    print("CLEANUP 1: Removing services from deleted accounts")
    print("="*70)
    
    supabase = get_supabase_client()
    
    # Get all deleted users
    users_resp = supabase.table('seva_auth_user').select(
        'id,username,email,is_active'
    ).execute()
    
    deleted_users = [u for u in (users_resp.data or []) if _is_deleted_user(u)]
    deleted_ids = [u['id'] for u in deleted_users]
    
    print(f"Found {len(deleted_users)} deleted accounts:")
    for u in deleted_users:
        print(f"  - ID {u['id']}: {u.get('username')} ({u.get('email')})")
    
    if not deleted_ids:
        print("No deleted accounts found")
        return 0
    
    # Find and remove their services
    services_resp = supabase.table('seva_service').select(
        'id,title,provider_id'
    ).in_('provider_id', deleted_ids).execute()
    
    bad_services = services_resp.data or []
    print(f"\nFound {len(bad_services)} services from deleted accounts:")
    
    deleted_count = 0
    for s in bad_services:
        try:
            supabase.table('seva_service').delete().eq('id', s['id']).execute()
            print(f"  ✓ Deleted service ID {s['id']}: {s.get('title')}")
            deleted_count += 1
        except Exception as e:
            print(f"  ✗ Error deleting service ID {s['id']}: {e}")
    
    print(f"\nTotal deleted: {deleted_count}/{len(bad_services)}")
    return deleted_count


def cleanup_duplicate_empty_services():
    """Remove duplicate services with 0.0 price and empty description."""
    print("\n" + "="*70)
    print("CLEANUP 2: Removing duplicate empty services")
    print("="*70)
    
    supabase = get_supabase_client()
    
    # Get all services
    services_resp = supabase.table('seva_service').select(
        'id,title,provider_id,price,description'
    ).execute()
    
    services = services_resp.data or []
    print(f"Total services in database: {len(services)}")
    
    # Group by (provider_id, title) and find duplicates with 0.0 price
    from collections import defaultdict
    service_groups = defaultdict(list)
    
    for s in services:
        key = (s.get('provider_id'), (s.get('title') or '').lower())
        service_groups[key].append(s)
    
    # Find groups with duplicates where some have 0.0 price
    duplicates_to_remove = []
    for (pid, title), group in service_groups.items():
        if len(group) > 1:
            # Sort by price (0.0 last) and description (empty last)
            group_sorted = sorted(group, key=lambda s: (
                s.get('price') == 0 or s.get('price') is None,
                not (s.get('description') or '').strip()
            ))
            
            # Keep the first (best) one, remove the rest
            for s in group_sorted[1:]:
                if s.get('price') == 0 or not (s.get('description') or '').strip():
                    duplicates_to_remove.append(s)
    
    print(f"Found {len(duplicates_to_remove)} duplicate services to remove")
    
    removed_count = 0
    for s in duplicates_to_remove:
        try:
            supabase.table('seva_service').delete().eq('id', s['id']).execute()
            print(f"  ✓ Deleted duplicate service ID {s['id']}: {s.get('title')} (price: {s.get('price')})")
            removed_count += 1
        except Exception as e:
            print(f"  ✗ Error deleting service ID {s['id']}: {e}")
    
    print(f"\nTotal removed: {removed_count}/{len(duplicates_to_remove)}")
    return removed_count


def report_mismatched_services():
    """Report services that might be mismatched (for manual review)."""
    print("\n" + "="*70)
    print("REPORT: Services that may be mismatched (manual review needed)")
    print("="*70)
    
    supabase = get_supabase_client()
    
    # Get all services and providers
    services_resp = supabase.table('seva_service').select(
        'id,title,provider_id,category_id'
    ).execute()
    
    providers_resp = supabase.table('seva_auth_user').select(
        'id,username,profession'
    ).execute()
    
    services = services_resp.data or []
    providers = {p['id']: p for p in (providers_resp.data or [])}
    
    # Known service-profession pairs (title contains profession)
    matching_pairs = {
        ('plumber', ['plumber']),
        ('electrician', ['electrician']),
        ('carpenter', ['carpenter']),
        ('tutor', ['tutor']),
        ('developer', ['developer', 'development']),
        ('makeup', ['makeup']),
        ('cleaning', ['cleaning', 'cleaner']),
        ('yoga', ['yoga']),
        ('truck', ['truck rental']),
        ('event', ['event planner']),
        ('courier', ['courier']),
        ('dj', ['dj']),
        ('appliance', ['appliance', 'repair']),
        ('mobile', ['mobile', 'repair']),
        ('massage', ['massage']),
        ('nurse', ['nurse', 'caretaker']),
        ('driver', ['driver']),
        ('caterer', ['catering', 'caterer']),
        ('physiotherapist', ['physio']),
        ('software', ['software', 'support']),
    }
    
    mismatches = []
    for s in services:
        pid = s.get('provider_id')
        provider = providers.get(pid)
        if not provider:
            continue
        
        title = (s.get('title') or '').lower()
        profession = (provider.get('profession') or '').lower()
        
        # Simple check: any word from profession in title
        has_match = any(
            prof_word in title
            for prof_word in profession.split()
            if len(prof_word) > 2
        )
        
        if not has_match and profession:
            mismatches.append({
                'id': s['id'],
                'provider': provider.get('username', 'Unknown'),
                'profession': profession,
                'service_title': (s.get('title') or '').strip(),
            })
    
    print(f"\nFound {len(mismatches)} potentially mismatched services")
    print("(These may need manual review or correction)")
    print("\nFirst 15:")
    for m in mismatches[:15]:
        print(f"  - {m['provider']} ({m['profession']}): '{m['service_title']}' [ID: {m['id']}]")
    
    if len(mismatches) > 15:
        print(f"  ... and {len(mismatches) - 15} more")
    
    return mismatches


def main():
    """Run all cleanup operations."""
    print("\n" + "="*70)
    print("DATABASE CLEANUP: Remove Corrupted Services")
    print("="*70)
    
    try:
        # Run cleanups
        deleted_count = cleanup_deleted_account_services()
        duplicate_count = cleanup_duplicate_empty_services()
        
        print("\n" + "="*70)
        print("CLEANUP SUMMARY")
        print("="*70)
        print(f"Services from deleted accounts removed: {deleted_count}")
        print(f"Duplicate empty services removed: {duplicate_count}")
        print(f"Total services removed: {deleted_count + duplicate_count}")
        
        # Report remaining mismatches
        mismatches = report_mismatched_services()
        
        print("\n" + "="*70)
        print("⚠ NOTE: Mismatched services above may need manual review")
        print("Consider removing or correcting these entries before production use")
        print("="*70)
        
    except Exception as e:
        print(f"\n✗ Error during cleanup: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    print("\n⚠ WARNING: This script will DELETE data from the database")
    print("Make sure you have a backup before proceeding!")
    response = input("\nDo you want to proceed? (yes/no): ").strip().lower()
    
    if response not in ('yes', 'y'):
        print("Cleanup cancelled")
        sys.exit(0)
    
    sys.exit(main())
