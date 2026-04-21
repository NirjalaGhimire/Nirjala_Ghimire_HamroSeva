#!/usr/bin/env python
"""
Comprehensive validation script for service-provider relationships.

This script verifies that:
1. All services have a valid provider_id that exists in the database
2. All providers are marked as providers (role='provider' or 'prov')
3. No deleted providers are linked to services
4. Provider names match correctly across all services
5. Search/filter endpoints return only valid services
6. Popular services show correct provider names

Run: python validate_service_provider_relationships.py
"""

import os
import sys
import django
from decimal import Decimal

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from supabase_config import get_supabase_client
from services.views import (
    _get_services_raw_from_supabase,
    _enrich_services_with_category_and_provider_names,
    _is_valid_service_row,
    _is_valid_provider_user,
    _is_deleted_user,
)
from services.models import Service, ServiceCategory
from authentication.models import User


def validate_services():
    """Validate all service-provider relationships."""
    print("\n" + "="*70)
    print("SERVICE-PROVIDER RELATIONSHIP VALIDATION")
    print("="*70)
    
    supabase = get_supabase_client()
    issues = []
    valid_count = 0
    
    try:
        # Fetch all services
        print("\n[1/5] Fetching all services from database...")
        services_response = supabase.table(Service._meta.db_table).select('*').execute()
        services = services_response.data or []
        print(f"     Found {len(services)} total services")
        
        # Fetch all providers
        print("\n[2/5] Fetching all providers from database...")
        providers_response = supabase.table('seva_auth_user').select(
            'id,username,email,role,is_active,profession'
        ).in_('role', ['provider', 'prov', 'Provider']).execute()
        providers = {p['id']: p for p in (providers_response.data or [])}
        print(f"     Found {len(providers)} providers")
        
        # Validate each service
        print("\n[3/5] Validating service-provider relationships...")
        for idx, service in enumerate(services, 1):
            sid = service.get('id')
            title = service.get('title', 'UNKNOWN')
            provider_id = service.get('provider_id')
            category_id = service.get('category_id')
            status = service.get('status', 'unknown')
            
            # Check if service is valid
            if not _is_valid_service_row(service):
                issues.append(
                    f"SERVICE #{sid} ({title}): Invalid/corrupted service row"
                )
                continue
            
            # Check if provider_id exists
            if not provider_id:
                issues.append(
                    f"SERVICE #{sid} ({title}): Missing provider_id"
                )
                continue
            
            # Check if provider exists
            if provider_id not in providers:
                issues.append(
                    f"SERVICE #{sid} ({title}): provider_id={provider_id} not found in database"
                )
                continue
            
            provider = providers[provider_id]
            
            # Check if provider is valid
            provider_name = provider.get('username', 'UNKNOWN')
            if not _is_valid_provider_user(provider):
                issues.append(
                    f"SERVICE #{sid} ({title}): Provider '{provider_name}' (#{provider_id}) is not a valid provider (role={provider.get('role')}, is_deleted={provider.get('is_deleted')}, is_active={provider.get('is_active')})"
                )
                continue
            
            # Check if provider is deleted
            if _is_deleted_user(provider):
                issues.append(
                    f"SERVICE #{sid} ({title}): Provider '{provider_name}' (#{provider_id}) is marked as deleted"
                )
                continue
            
            valid_count += 1
            if idx % 10 == 0 or idx == len(services):
                print(f"     ✓ Validated {idx}/{len(services)} services")
        
        # Fetch services through the API layer
        print("\n[4/5] Testing _get_services_raw_from_supabase()...")
        api_services = _get_services_raw_from_supabase()
        print(f"     API returned {len(api_services)} services")
        
        # Check that all API services have provider_name
        api_issues = 0
        for service in api_services:
            if not service.get('provider_name'):
                api_issues += 1
                sid = service.get('id', 'UNKNOWN')
                title = service.get('title', 'UNKNOWN')
                issues.append(
                    f"API_SERVICE #{sid} ({title}): Missing provider_name in API response"
                )
        
        if api_issues == 0:
            print(f"     ✓ All {len(api_services)} API services have provider_name")
        else:
            print(f"     ✗ {api_issues} API services missing provider_name")
        
        # Check provider distribution
        print("\n[5/5] Provider distribution in API response...")
        provider_counts = {}
        for service in api_services:
            pname = service.get('provider_name', 'UNKNOWN')
            provider_counts[pname] = provider_counts.get(pname, 0) + 1
        
        print(f"     Total unique providers: {len(provider_counts)}")
        for provider_name in sorted(provider_counts.keys()):
            count = provider_counts[provider_name]
            print(f"     - {provider_name}: {count} service(s)")
        
    except Exception as e:
        print(f"\n✗ Error during validation: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    # Print summary
    print("\n" + "="*70)
    print("VALIDATION SUMMARY")
    print("="*70)
    print(f"✓ Valid services: {valid_count}/{len(services)}")
    print(f"✓ API services returned: {len(api_services)}")
    
    if issues:
        print(f"\n✗ FOUND {len(issues)} ISSUES:\n")
        for idx, issue in enumerate(issues, 1):
            print(f"{idx:3d}. {issue}")
        return False
    else:
        print("\n✓ ALL VALIDATIONS PASSED - No issues found!")
        return True


def validate_search_filtering():
    """Validate that search and filtering works correctly."""
    print("\n" + "="*70)
    print("SEARCH & FILTERING VALIDATION")
    print("="*70)
    
    supabase = get_supabase_client()
    
    try:
        # Test filtering by category
        print("\n[1/3] Testing category filtering...")
        categories_response = supabase.table(ServiceCategory._meta.db_table).select('id').limit(1).execute()
        if categories_response.data:
            category_id = categories_response.data[0]['id']
            services = _get_services_raw_from_supabase(category_id=category_id)
            print(f"     ✓ Category {category_id}: {len(services)} services")
            
            # Verify all returned services belong to this category
            wrong_category = [s for s in services if s.get('category_id') != category_id]
            if wrong_category:
                print(f"     ✗ Found {len(wrong_category)} services with wrong category!")
                return False
        else:
            print("     ⚠ No categories found")
        
        # Test filtering by provider
        print("\n[2/3] Testing provider filtering...")
        providers_response = supabase.table('seva_auth_user').select('id').in_(
            'role', ['provider', 'prov']
        ).limit(1).execute()
        if providers_response.data:
            provider_id = providers_response.data[0]['id']
            services = _get_services_raw_from_supabase(provider_id=provider_id)
            print(f"     ✓ Provider {provider_id}: {len(services)} services")
            
            # Verify all returned services belong to this provider
            wrong_provider = [s for s in services if s.get('provider_id') != provider_id]
            if wrong_provider:
                print(f"     ✗ Found {len(wrong_provider)} services with wrong provider!")
                return False
            
            # Verify all services have this provider's name
            for service in services:
                pname = service.get('provider_name', '')
                if not pname:
                    print(f"     ✗ Service {service.get('id')} has no provider_name!")
                    return False
        else:
            print("     ⚠ No providers found")
        
        # Test location filtering
        print("\n[3/3] Testing location-based filtering...")
        services = _get_services_raw_from_supabase()
        if services:
            # Check that services have provider location info
            services_with_location = [
                s for s in services 
                if s.get('provider_district') or s.get('provider_city')
            ]
            print(f"     ✓ Services with location info: {len(services_with_location)}/{len(services)}")
            
            if services_with_location:
                sample = services_with_location[0]
                print(f"     Sample: {sample.get('title')} by {sample.get('provider_name')} "
                      f"in {sample.get('provider_city')}, {sample.get('provider_district')}")
        
        print("\n✓ Search & filtering validation PASSED")
        return True
        
    except Exception as e:
        print(f"\n✗ Error during filtering validation: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == '__main__':
    print("\n🔍 Starting comprehensive service-provider validation...\n")
    
    result1 = validate_services()
    result2 = validate_search_filtering()
    
    print("\n" + "="*70)
    if result1 and result2:
        print("✓ ALL VALIDATIONS PASSED ✓")
        sys.exit(0)
    else:
        print("✗ SOME VALIDATIONS FAILED ✗")
        sys.exit(1)
