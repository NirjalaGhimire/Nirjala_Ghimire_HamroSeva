"""
Pull real provider/service rows from Supabase (same data the app already uses).
No fake data — only what exists in seva_service / seva_review / provider profiles.
"""
from __future__ import annotations

import logging
import re
from collections import defaultdict
from typing import Any, Dict, List, Optional, Tuple

from supabase_config import get_supabase_client

# Reuse the same enrichment + verification logic as the public services API
from services.views import (
    _filter_services_by_provider_location,
    _get_services_raw_from_supabase,
)

logger = logging.getLogger(__name__)

# Common Nepal place tokens (lowercase) → filter hint for provider_district / provider_city
PLACE_ALIASES = (
    'kathmandu',
    'lalitpur',
    'bhaktapur',
    'pokhara',
    'biratnagar',
    'birgunj',
    'dharan',
    'hetauda',
    'butwal',
    'nepalgunj',
    'chitwan',
    'janakpur',
)

# Words that suggest sorting / filters
VERIFIED_WORDS = ('verified', 'verification', 'trust', 'approved')
CHEAP_WORDS = ('cheap', 'affordable', 'lowest', 'budget', 'economical', 'less expensive')
BEST_WORDS = ('best', 'top', 'highest', 'rating', 'rated', 'review', 'popular', 'great')
ALL_SERVICES_WORDS = (
    'all services',
    'services available',
    'what services',
    'list services',
    'services does this app provide',
    'app provides',
)
ALL_PROVIDERS_WORDS = (
    'all providers',
    'list providers',
    'verified providers',
    'verified users',
)
GENERIC_QUERY_STOPWORDS = {
    'what',
    'which',
    'where',
    'when',
    'how',
    'who',
    'this',
    'that',
    'these',
    'those',
    'your',
    'you',
    'for',
    'from',
    'with',
    'near',
    'app',
    'provide',
    'provides',
    'provided',
    'service',
    'services',
    'provider',
    'providers',
    'user',
    'users',
    'list',
    'show',
    'tell',
    'about',
    'available',
    'customer',
}


def _fetch_review_stats_by_provider() -> Dict[int, Dict[str, float]]:
    """Average rating and count per provider from seva_review."""
    supabase = get_supabase_client()
    out: Dict[int, Dict[str, float]] = defaultdict(lambda: {'sum': 0.0, 'count': 0.0})
    try:
        r = supabase.table('seva_review').select('provider_id,rating').execute()
    except Exception as e:
        logger.warning('Could not load reviews for AI retrieval: %s', e)
        return {}
    for row in r.data or []:
        pid = row.get('provider_id')
        rating = row.get('rating')
        if pid is None or rating is None:
            continue
        try:
            rv = float(rating)
        except (TypeError, ValueError):
            continue
        pid = int(pid)
        out[pid]['sum'] += rv
        out[pid]['count'] += 1.0
    stats = {}
    for pid, agg in out.items():
        c = int(agg['count'])
        if c == 0:
            continue
        stats[pid] = {
            'review_count': c,
            'avg_rating': round(agg['sum'] / c, 2),
        }
    return stats


def _load_category_names() -> List[Tuple[int, str]]:
    supabase = get_supabase_client()
    try:
        r = supabase.table('seva_servicecategory').select('id,name').execute()
    except Exception as e:
        logger.warning('Could not load categories: %s', e)
        return []
    rows = []
    for row in r.data or []:
        cid = row.get('id')
        name = (row.get('name') or '').strip()
        if cid is not None and name:
            rows.append((int(cid), name))
    return rows


def _parse_intent(query: str) -> Dict[str, Any]:
    """Lightweight keyword intent — no ML here, keeps behavior predictable."""
    q = (query or '').strip().lower()
    intent: Dict[str, Any] = {
        'verified_only': any(w in q for w in VERIFIED_WORDS),
        'sort_cheap': any(w in q for w in CHEAP_WORDS),
        'sort_best': any(w in q for w in BEST_WORDS),
        'location_terms': [p for p in PLACE_ALIASES if p in q],
        'category_ids': [],
        'request_all_services': any(w in q for w in ALL_SERVICES_WORDS),
        'request_all_providers': any(w in q for w in ALL_PROVIDERS_WORDS),
    }

    categories = _load_category_names()
    for cid, name in categories:
        nl = name.lower()
        if len(nl) < 3:
            continue
        if nl in q:
            intent['category_ids'].append(cid)
            continue
        # Match multi-word category names (e.g. "beauty" inside "Beauty & Wellness")
        for part in re.split(r'[\s/&,-]+', nl):
            if len(part) >= 4 and part in q:
                intent['category_ids'].append(cid)
                break

    # De-dupe category ids
    intent['category_ids'] = list(dict.fromkeys(intent['category_ids']))
    return intent


def _to_float_price(row: Dict[str, Any]) -> float:
    p = row.get('price')
    if p is None:
        return 0.0
    try:
        return float(p)
    except (TypeError, ValueError):
        return 0.0


def _keyword_narrow(services: List[Dict[str, Any]], query: str) -> List[Dict[str, Any]]:
    """If the user names a trade (e.g. electrician), match title/profession/category text."""
    q = (query or '').lower()
    tokens = [
        t
        for t in re.split(r'[\s,./+&\-]+', q)
        if len(t) >= 4 and t not in GENERIC_QUERY_STOPWORDS
    ]
    if not tokens:
        return services
    out = []
    for s in services:
        blob = ' '.join(
            [
                str(s.get('category_name') or ''),
                str(s.get('provider_profession') or ''),
                str(s.get('title') or ''),
            ]
        ).lower()
        if any(t in blob for t in tokens):
            out.append(s)
    return out if out else services


def retrieve_for_query(query: str, *, limit: int = 12) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    """
    Returns (ranked_rows, debug_meta).
    Each row is a plain dict safe to JSON — only real DB fields.
    """
    intent = _parse_intent(query)
    services = _get_services_raw_from_supabase()
    if not services:
        return [], {'intent': intent, 'message': 'no_services_in_db'}

    should_show_all = (
        intent['request_all_services']
        or intent['request_all_providers']
        or (intent['verified_only'] and not intent['location_terms'] and not intent['category_ids'])
    )

    # Optional category filter
    if intent['category_ids']:
        cids = set(intent['category_ids'])
        services = [s for s in services if s.get('category_id') in cids]
    elif not should_show_all:
        # No category name hit: narrow by keywords in profession/title
        services = _keyword_narrow(services, query)

    # Location: use existing filter helper (district/city exact match)
    # Map first matched place token to a city filter (common pattern in your DB)
    if intent['location_terms']:
        # Prefer city match; many rows store city name under provider_city
        term = intent['location_terms'][0]
        title = term.title()  # e.g. Kathmandu
        services = _filter_services_by_provider_location(services, '', title)
        if not services:
            services = _get_services_raw_from_supabase()
            if intent['category_ids']:
                cids = set(intent['category_ids'])
                services = [s for s in services if s.get('category_id') in cids]
            else:
                services = _keyword_narrow(services, query)
            services = _filter_services_by_provider_location(services, title, '')

    # Verified-only: use flags from enrichment
    if intent['verified_only']:
        services = [s for s in services if s.get('provider_is_verified') is True]

    review_stats = _fetch_review_stats_by_provider()

    enriched: List[Dict[str, Any]] = []
    for s in services:
        pid = s.get('provider_id')
        st = review_stats.get(int(pid)) if pid is not None else None
        avg = st['avg_rating'] if st else None
        cnt = int(st['review_count']) if st else 0
        row = {
            'service_id': s.get('id'),
            'provider_id': pid,
            'provider_name': s.get('provider_name') or '',
            'service_title': (s.get('title') or '').strip(),
            'category_name': (s.get('category_name') or '').strip(),
            'price': _to_float_price(s),
            'location': (s.get('location') or '').strip(),
            'provider_district': (s.get('provider_district') or '').strip(),
            'provider_city': (s.get('provider_city') or '').strip(),
            'provider_profession': (s.get('provider_profession') or '').strip(),
            'verification_status': (s.get('provider_verification_status') or 'unverified'),
            'is_verified': bool(s.get('provider_is_verified')),
            'avg_rating': avg,
            'review_count': cnt,
        }
        enriched.append(row)

    dedupe_by_provider = not intent['request_all_services']
    if dedupe_by_provider:
        # Dedupe by provider: keep the best row per provider for ranking.
        by_pid: Dict[Any, Dict[str, Any]] = {}
        for row in enriched:
            pid = row['provider_id']
            if pid is None:
                continue
            prev = by_pid.get(pid)
            if prev is None:
                by_pid[pid] = row
                continue

            def score(r: Dict[str, Any]) -> Tuple:
                ar = r['avg_rating'] or 0.0
                return (r['review_count'], ar, -r['price'])

            if score(row) > score(prev):
                by_pid[pid] = row
        ranked = list(by_pid.values())
    else:
        ranked = list(enriched)

    if intent['sort_cheap'] and not intent['sort_best']:
        ranked.sort(key=lambda r: (r['price'] if r['price'] > 0 else 1e9))
    else:
        # Default and "best": avg_rating desc, then review_count desc
        ranked.sort(
            key=lambda r: (
                r['avg_rating'] or 0.0,
                r['review_count'],
                1.0 / (r['price'] + 0.01) if r['price'] > 0 else 0,
            ),
            reverse=True,
        )

    effective_limit = max(1, int(limit or 12))
    return ranked[:effective_limit], {
        'intent': intent,
        'total_candidates': len(ranked),
        'returned': min(len(ranked), effective_limit),
    }


def format_context_for_llm(rows: List[Dict[str, Any]]) -> str:
    """Compact text block for the model — instruct it not to invent beyond this list."""
    if not rows:
        return '(No matching provider/service rows were found in the database.)'
    lines = []
    for i, r in enumerate(rows, 1):
        avg = r.get('avg_rating')
        rc = r.get('review_count') or 0
        rating_part = f"avg_rating={avg}, reviews={rc}" if avg is not None else f"reviews={rc}"
        lines.append(
            f"{i}. {r.get('provider_name') or 'Provider'} — "
            f"{r.get('service_title') or 'Service'} "
            f"({r.get('category_name') or 'Category'}) | "
            f"Rs {r.get('price') or 0} | "
            f"{r.get('provider_district') or ''} {r.get('provider_city') or ''} | "
            f"{rating_part} | "
            f"verified={'yes' if r.get('is_verified') else 'no'}"
        )
    return '\n'.join(lines)
