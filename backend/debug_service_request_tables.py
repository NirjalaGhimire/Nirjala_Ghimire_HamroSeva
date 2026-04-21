#!/usr/bin/env python
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from supabase_config import get_supabase_client

supabase = get_supabase_client()

candidates = [
    'seva_service_category_request',
    'seva_servicecategoryrequest',
    'seva_service_category_requests',
    'seva_servicecategory_request',
]

for table in candidates:
    try:
        r = supabase.table(table).select('id').limit(1).execute()
        count = len(r.data or [])
        print(f'OK: {table} (sample rows: {count})')
    except Exception as e:
        print(f'NO: {table} -> {e}')
