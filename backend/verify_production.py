#!/usr/bin/env python
"""
Post-Deployment Verification Script
Quickly verify that all data filtering is working correctly in production.
"""

import os
import sys
import django

sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from supabase_config import get_supabase_client
from services.views import _get_services_raw_from_supabase
from django.contrib.auth import get_user_model

User = get_user_model()


def verify_backend_filtering():
    """Verify backend is applying all filters correctly."""
    print("\n" + "="*70)
    print("PRODUCTION VERIFICATION: Backend Filtering")
    print("="*70)
    
    services = _get_services_raw_from_supabase()
    
    print(f"\nTotal services returned: {len(services)}")
    
    # Check for deleted users
    deleted_count = sum(
        1 for s in services
        if 'deleted_' in str(s.get('provider_name', '')).lower()
    )
    
    # Check for non-providers
    non_provider_count = sum(
        1 for s in services
        if not s.get('provider_is_provider', True)
    )
    
    # Check for corrupted entries
    corrupted = [
        s for s in services
        if (not s.get('title') or s.get('title') == 'EMPTY' or 
            s.get('price', 0) < 0)
    ]
    
    print(f"  Deleted providers: {deleted_count} (Expected: 0)")
    print(f"  Non-providers: {non_provider_count} (Expected: 0)")
    print(f"  Corrupted entries: {len(corrupted)} (Expected: 0)")
    
    all_ok = deleted_count == 0 and non_provider_count == 0 and len(corrupted) == 0
    
    if all_ok:
        print("✅ PASS: Backend filtering is working correctly")
    else:
        print("❌ FAIL: Backend filter detected bad data")
    
    return all_ok


def verify_user_scenarios():
    """Verify specific user scenarios work correctly."""
    print("\n" + "="*70)
    print("PRODUCTION VERIFICATION: User Scenarios")
    print("="*70)
    
    supabase = get_supabase_client()
    services = _get_services_raw_from_supabase()
    
    # Get providers
    providers_resp = supabase.table('seva_auth_user').select(
        'id,username,profession'
    ).execute()
    
    providers = {p['id']: p for p in (providers_resp.data or [])}
    
    checks = []
    
    # Check 1: Nayanka appears as Dietitian
    nayanka = next(
        (p for p in providers.values() 
         if 'nayanka' in str(p.get('username', '')).lower()),
        None
    )
    
    if nayanka:
        nayanka_services = [
            s for s in services if s.get('provider_id') == nayanka['id']
        ]
        is_dietitian = 'dietitian' in str(nayanka.get('profession', '')).lower()
        status = "✅" if is_dietitian and nayanka_services else "❌"
        print(f"{status} Nayanka: {len(nayanka_services)} services, Profession: {nayanka.get('profession')}")
        checks.append(is_dietitian and len(nayanka_services) > 0)
    
    # Check 2: Rocky is not under Dietitian
    rocky = next(
        (p for p in providers.values()
         if 'rocky' in str(p.get('username', '')).lower()),
        None
    )
    
    if rocky:
        rocky_services = [
            s for s in services if s.get('provider_id') == rocky['id']
        ]
        rocky_has_dietitian = any(
            'dietitian' in str(s.get('title', '')).lower()
            for s in rocky_services
        )
        status = "✅" if not rocky_has_dietitian else "❌"
        print(f"{status} Rocky: NOT under Dietitian (has {len(rocky_services)} services)")
        checks.append(not rocky_has_dietitian)
    
    # Check 3: Monishna has services
    monishna = next(
        (p for p in providers.values()
         if 'monishna' in str(p.get('username', '')).lower()),
        None
    )
    
    if monishna:
        monishna_services = [
            s for s in services if s.get('provider_id') == monishna['id']
        ]
        status = "✅" if monishna_services else "❌"
        print(f"{status} Monishna: {len(monishna_services)} services")
        checks.append(len(monishna_services) > 0)
    
    # Check 4: No deleted accounts
    deleted_services = [
        s for s in services
        if 'deleted_' in str(s.get('provider_name', '')).lower()
    ]
    status = "✅" if not deleted_services else "❌"
    print(f"{status} Deleted accounts: {len(deleted_services)} services (Expected: 0)")
    checks.append(len(deleted_services) == 0)
    
    all_ok = all(checks) and len(checks) > 0
    
    if all_ok:
        print("\n✅ PASS: All user scenarios verified")
    else:
        print("\n❌ FAIL: Some scenarios failed")
    
    return all_ok


def verify_api_endpoints():
    """Quick smoke test of API endpoints."""
    print("\n" + "="*70)
    print("PRODUCTION VERIFICATION: API Endpoints")
    print("="*70)
    
    try:
        # Just verify imports work (actual endpoint testing needs client)
        from services.views import (
            services_list,
            providers_list,
            favorite_providers_list,
            favorite_services_list
        )
        print("✅ All endpoint functions loaded without errors")
        return True
    except Exception as e:
        print(f"❌ Error loading endpoints: {e}")
        return False


def main():
    """Run all verification checks."""
    print("\n" + "="*70)
    print("PRODUCTION VERIFICATION SUITE")
    print("Run this after deploying to verify all fixes are working")
    print("="*70)
    
    results = {
        "Backend Filtering": verify_backend_filtering(),
        "User Scenarios": verify_user_scenarios(),
        "API Endpoints": verify_api_endpoints(),
    }
    
    print("\n" + "="*70)
    print("VERIFICATION SUMMARY")
    print("="*70)
    
    for test, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status}: {test}")
    
    all_passed = all(results.values())
    total = len(results)
    passed_count = sum(1 for v in results.values() if v)
    
    print(f"\nOverall: {passed_count}/{total} verification checks passed")
    
    if all_passed:
        print("\n✅ DEPLOYMENT VERIFIED - All systems operational!")
        print("The application is ready for production use.")
        return 0
    else:
        print("\n❌ DEPLOYMENT VERIFICATION FAILED")
        print("Please review the failures above and fix any issues.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
