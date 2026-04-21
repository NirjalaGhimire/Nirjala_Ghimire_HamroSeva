"""
Provider ↔ service rows (seva_service): upsert, dedupe, registration sync.

The app stores offerings as rows in seva_service (provider_id + category_id + title).
Duplicates in the UI usually come from multiple DB rows for the same provider + same
display title (different prices). Browse API no longer clones rows across "equivalent" titles.

We dedupe API responses by (provider_id, normalized title) so each provider appears once
per selected subcategory.
"""
from decimal import Decimal

from supabase_config import get_supabase_client
from .models import Service, ServiceCategory
from .category_matching import provider_profession_matches_category
from .service_name_utils import (
    dedupe_services_offered_list,
    find_row_with_normalized_title,
    format_service_title_display,
    normalize_service_key,
)


def dedupe_services_by_provider_and_title(services):
    """
    Keep one row per (provider_id, normalized title) — lowest seva_service id wins (stable).

    This removes duplicate "Radha" cards when the same provider has two rows that
    both match the selected subcategory (e.g. equivalent-title expansion + DB dup).
    """
    if not services:
        return services
    best = {}  # (pid, normalized_key) -> row
    for s in services:
        pid = s.get('provider_id')
        title = (s.get('title') or '').strip()
        if pid is None:
            continue
        key = (pid, normalize_service_key(title))
        try:
            sid = int(s.get('id') or 0)
        except (TypeError, ValueError):
            sid = 0
        row = dict(s)
        row['title'] = format_service_title_display(title)
        if key not in best:
            best[key] = row
            continue
        ex = best[key]
        try:
            ex_id = int(ex.get('id') or 0)
        except (TypeError, ValueError):
            ex_id = 0
        if sid and (not ex_id or sid < ex_id):
            best[key] = row
    return list(best.values())


def _resolve_category_for_profession(profession: str):
    """
    Pick category_id for a new provider profession.

    Priority:
    1) Strict rules (provider_profession_matches_category) — never trust mis-seeded DB alone.
    2) Fallback: seva_service rows with same title only if category passes strict check.
    """
    profession = (profession or '').strip()
    if not profession:
        return None, None
    supabase = get_supabase_client()
    table = Service._meta.db_table
    display = format_service_title_display(profession)

    # 1) Authoritative: first category (by name) whose rules accept this profession
    try:
        r = supabase.table(ServiceCategory._meta.db_table).select('id,name').execute()
        for c in sorted((r.data or []), key=lambda x: (x.get('name') or '')):
            cat_name = (c.get('name') or '').strip()
            if provider_profession_matches_category(profession, cat_name):
                return c.get('id'), cat_name
    except Exception as e:
        print(f'_resolve_category_for_profession category scan: {e}')

    # 2) Fallback: existing catalog rows with same title — only if strict rules agree
    try:
        cids = []
        for t in (profession, display):
            r = supabase.table(table).select('category_id').eq('title', t).execute()
            cids.extend([row['category_id'] for row in (r.data or []) if row.get('category_id')])
        cids = list({c for c in cids if c})
        for cid in cids:
            cr = supabase.table(ServiceCategory._meta.db_table).select('name').eq('id', cid).execute()
            name = (cr.data[0].get('name') or '') if cr.data else ''
            if provider_profession_matches_category(profession, name):
                return cid, name
    except Exception as e:
        print(f'_resolve_category_for_profession title match: {e}')

    return None, None


def ensure_provider_default_service(provider_id, profession):
    """Insert one seva_service row for signup when no explicit services_offered were sent."""
    raw = (profession or '').strip()
    if not raw or not provider_id:
        return
    display = format_service_title_display(raw)
    try:
        supabase = get_supabase_client()
        category_id, category_name = _resolve_category_for_profession(raw)
        if not category_id:
            return
        try:
            cid = int(category_id)
        except (TypeError, ValueError):
            return
        existing = supabase.table(Service._meta.db_table).select('id,title').eq(
            'provider_id', provider_id
        ).eq('category_id', cid).execute()
        if find_row_with_normalized_title(existing.data or [], raw):
            return
        supabase.table(Service._meta.db_table).insert({
            'provider_id': provider_id,
            'category_id': cid,
            'title': display,
            'description': '',
            'price': 0,
            'duration_minutes': 60,
            'location': '',
            'status': 'active',
        }).execute()
        print(f"✅ Created default service for provider {provider_id} ({display}) in category {category_name}")
    except Exception as e:
        print(f"ensure_provider_default_service warning: {e}")


def ensure_provider_service_in_category(provider_id, profession, category_id, category_name):
    """
    Ensure provider has a seva_service row in the *given* category (browse/discovery).

    Unlike ensure_provider_default_service(), this does not use _resolve_category_for_profession(),
    which can pick the wrong category when the same title exists elsewhere (e.g. provider stuck
    under Education while customers browse Healthcare — they would never see the provider).
    """
    raw = (profession or '').strip()
    category_name = (category_name or '').strip()
    if not raw or not provider_id or not category_id:
        return
    if not provider_profession_matches_category(raw, category_name):
        return
    display = format_service_title_display(raw)
    try:
        supabase = get_supabase_client()
        try:
            cid = int(category_id)
        except (TypeError, ValueError):
            return
        existing = supabase.table(Service._meta.db_table).select('id,title').eq(
            'provider_id', provider_id
        ).eq('category_id', cid).execute()
        if find_row_with_normalized_title(existing.data or [], raw):
            return
        supabase.table(Service._meta.db_table).insert({
            'provider_id': provider_id,
            'category_id': cid,
            'title': display,
            'description': '',
            'price': 0,
            'duration_minutes': 60,
            'location': '',
            'status': 'active',
        }).execute()
        print(f"✅ ensure_provider_service_in_category: provider {provider_id} ({display}) in category {category_name} (id={cid})")
    except Exception as e:
        print(f"ensure_provider_service_in_category warning: {e}")


def upsert_provider_service_row(provider_id, category_id, title, price=None):
    """Insert a service row if (provider, category, normalized title) does not exist yet."""
    raw = (title or '').strip()
    if not raw or not provider_id or not category_id:
        return
    display = format_service_title_display(raw)
    if price is None:
        price = Decimal('0')
    supabase = get_supabase_client()
    try:
        cid = int(category_id)
    except (TypeError, ValueError):
        return
    try:
        cr = supabase.table(ServiceCategory._meta.db_table).select('name').eq('id', cid).execute()
        cname = (cr.data[0].get('name') or '') if cr.data else ''
        if cname and not catalog_service_title_matches_category(display, cname):
            print(
                f'upsert_provider_service_row: rejected "{display}" for category "{cname}"'
            )
            return
    except Exception as e:
        print(f'upsert_provider_service_row category check: {e}')
    try:
        r = supabase.table(Service._meta.db_table).select('id,title').eq(
            'provider_id', provider_id
        ).eq('category_id', cid).execute()
        if find_row_with_normalized_title(r.data or [], raw):
            return
        supabase.table(Service._meta.db_table).insert({
            'provider_id': provider_id,
            'category_id': cid,
            'title': display,
            'description': '',
            'price': float(price),
            'duration_minutes': 60,
            'location': '',
            'status': 'active',
        }).execute()
    except Exception as e:
        print(f'upsert_provider_service_row: {e}')


def sync_services_offered(provider_id, services_offered):
    """
    services_offered: list of {"category_id": int, "title": str} from registration.
    Creates one seva_service per item; skips duplicates by normalized title per category.
    """
    if not provider_id or not services_offered:
        return
    clean = dedupe_services_offered_list(services_offered)
    for item in clean:
        upsert_provider_service_row(provider_id, item['category_id'], item['title'], Decimal('0'))
