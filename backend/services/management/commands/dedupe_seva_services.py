"""
Merge duplicate seva_service rows (same category_id + normalized title).

Usage (from backend directory, Django configured):
  python manage.py dedupe_seva_services

Updates seva_booking.service_id to the canonical row (minimum id per group),
deletes duplicate service rows, and sets canonical title to Title Case.

Review output before running on production; backup first.
"""
from collections import defaultdict

from django.core.management.base import BaseCommand

from supabase_config import get_supabase_client
from services.models import Booking, Service
from services.service_name_utils import format_service_title_display, normalize_service_key


class Command(BaseCommand):
    help = 'Merge duplicate seva_service rows per (category_id, normalized title)'

    def handle(self, *args, **options):
        supabase = get_supabase_client()
        table = 'seva_service'
        r = supabase.table(table).select('id,category_id,title').execute()
        rows = r.data or []
        groups = defaultdict(list)
        for row in rows:
            cid = row.get('category_id')
            raw = (row.get('title') or '').strip()
            key = (cid, normalize_service_key(raw))
            groups[key].append(row)

        merged = 0
        for key, grp in groups.items():
            if len(grp) < 2:
                continue
            grp.sort(key=lambda x: int(x.get('id') or 0))
            keep = grp[0]
            keep_id = int(keep['id'])
            canonical_title = format_service_title_display(keep.get('title'))
            dup_ids = [int(x['id']) for x in grp[1:]]

            for old_id in dup_ids:
                try:
                    supabase.table(Booking._meta.db_table).update({'service_id': keep_id}).eq(
                        'service_id', old_id
                    ).execute()
                except Exception as e:
                    self.stderr.write(f'Booking update {old_id} -> {keep_id}: {e}')
                try:
                    supabase.table(table).delete().eq('id', old_id).execute()
                    merged += 1
                except Exception as e:
                    self.stderr.write(f'Delete service {old_id}: {e}')

            try:
                supabase.table(table).update({'title': canonical_title}).eq('id', keep_id).execute()
            except Exception as e:
                self.stderr.write(f'Update title on {keep_id}: {e}')

        self.stdout.write(self.style.SUCCESS(f'Done. Removed {merged} duplicate service row(s).'))
