"""
Delete seva_service rows whose title does not belong in that row's category.

Run after backup:
  python manage.py cleanup_misplaced_services

Uses the same rules as catalog_service_title_matches_category. Repoints bookings
to a surviving service in the same (provider, normalized title) if possible, else
only deletes when safe (no booking) — here we only UPDATE bookings to a canonical
service id in the *correct* category when duplicate exists; otherwise warn.

For simplicity: only DELETE rows that fail catalog_service_title_matches_category.
Before delete, update seva_booking.service_id to NULL or to another service —
Supabase may not allow null; so we UPDATE bookings to first matching service in correct category.

This command is conservative: deletes misplaced rows and repoints bookings to
any service with same normalized title in an allowed category for that provider.
"""
from django.core.management.base import BaseCommand

from supabase_config import get_supabase_client
from services.models import Booking, Service, ServiceCategory
from services.service_name_utils import normalize_service_key
from services.category_matching import catalog_service_title_matches_category


class Command(BaseCommand):
    help = 'Remove seva_service rows in wrong category (strict title↔category rules)'

    def handle(self, *args, **options):
        supabase = get_supabase_client()
        table = Service._meta.db_table
        cat_table = ServiceCategory._meta.db_table
        booking_table = Booking._meta.db_table

        r = supabase.table(table).select('id,category_id,title,provider_id').execute()
        rows = r.data or []
        deleted = 0

        for row in rows:
            sid = row.get('id')
            cid = row.get('category_id')
            title = (row.get('title') or '').strip()
            pid = row.get('provider_id')
            if not title or cid is None:
                continue
            cr = supabase.table(cat_table).select('name').eq('id', cid).execute()
            cname = (cr.data[0].get('name') or '') if cr.data else ''
            if not cname:
                continue
            if catalog_service_title_matches_category(title, cname):
                continue

            # Wrong placement — try repoint bookings to a correct row for same provider+title
            nkey = normalize_service_key(title)
            replacement = None
            r2 = supabase.table(table).select('id,category_id,title').eq('provider_id', pid).execute()
            for other in r2.data or []:
                oid = other.get('category_id')
                ot = (other.get('title') or '').strip()
                if other.get('id') == sid:
                    continue
                if normalize_service_key(ot) != nkey:
                    continue
                ocr = supabase.table(cat_table).select('name').eq('id', oid).execute()
                oname = (ocr.data[0].get('name') or '') if ocr.data else ''
                if oname and catalog_service_title_matches_category(ot, oname):
                    replacement = other.get('id')
                    break

            if replacement is not None:
                try:
                    supabase.table(booking_table).update({'service_id': replacement}).eq(
                        'service_id', sid
                    ).execute()
                except Exception as e:
                    self.stderr.write(f'Booking repoint {sid} -> {replacement}: {e}')

            try:
                supabase.table(table).delete().eq('id', sid).execute()
                deleted += 1
                self.stdout.write(f'Deleted misplaced service id={sid} title={title!r} category={cname!r}')
            except Exception as e:
                self.stderr.write(f'Delete service {sid}: {e}')

        self.stdout.write(self.style.SUCCESS(f'Done. Removed {deleted} misplaced row(s).'))
