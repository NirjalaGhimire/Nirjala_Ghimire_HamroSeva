"""
Canonical service name handling for seva_service titles.

- normalized_key: trim, collapse whitespace, lowercase — used for duplicate detection.
- format_service_title_display: professional Title Case for storage and UI.
"""
from __future__ import annotations

import re
from typing import Iterable, List


def normalize_service_key(name: str | None) -> str:
    """
    Canonical comparison key: trim, single spaces, lowercase.
    Same as: service.trim().replace(/\\s+/g, ' ').toLowerCase() in JS.
    """
    if name is None:
        return ""
    return " ".join(str(name).strip().split()).lower()


def format_service_title_display(name: str | None) -> str:
    """
    Display / storage format: collapse spaces, title-case each word.
    Preserves standalone '&' (e.g. 'Beauty & Wellness').
    Hyphenated segments are capitalized per segment (e.g. 'Self-Service').
    """
    s = " ".join(str(name or "").strip().split())
    if not s:
        return ""
    # Common typo: "Application Repair" → Appliance
    if re.search(r"application\s+repair", s, re.IGNORECASE):
        s = re.sub(r"application", "Appliance", s, count=1, flags=re.IGNORECASE)

    def cap_word(w: str) -> str:
        if not w:
            return w
        if w == "&":
            return "&"
        if "-" in w:
            return "-".join(part.capitalize() for part in w.split("-"))
        return w.capitalize()

    return " ".join(cap_word(w) for w in s.split(" "))


def dedupe_services_offered_list(items: Iterable[dict]) -> List[dict]:
    """
    Deduplicate [{category_id, title}, ...] by (category_id, normalized_key).
    Returns [{'category_id': int, 'title': canonical_display}, ...] in first-seen order.
    """
    from collections import OrderedDict

    out: "OrderedDict[tuple[int, str], dict]" = OrderedDict()
    for item in items:
        if not isinstance(item, dict):
            continue
        try:
            cid = int(item.get("category_id"))
        except (TypeError, ValueError):
            continue
        raw = (item.get("title") or "").strip()
        if not raw:
            continue
        nkey = normalize_service_key(raw)
        key = (cid, nkey)
        if key in out:
            continue
        out[key] = {
            "category_id": cid,
            "title": format_service_title_display(raw),
        }
    return list(out.values())


def find_row_with_normalized_title(rows: Iterable[dict], title_raw: str) -> dict | None:
    """
    Return first row whose title matches title_raw by normalized key.
    Rows should already be scoped (e.g. same provider + category query).
    """
    want = normalize_service_key(title_raw)
    if not want:
        return None
    for row in rows or []:
        if normalize_service_key(row.get("title")) == want:
            return row
    return None


def dedupe_catalog_signup_rows(services: List[dict]) -> List[dict]:
    """
    Provider registration / catalog: one row per (category_id, normalized title).
    Keeps the row with the smallest id; sets title to format_service_title_display.
    """
    from collections import OrderedDict

    best: "OrderedDict[tuple, dict]" = OrderedDict()
    for s in services:
        cat_id = s.get("category_id")
        raw = (s.get("title") or "").strip()
        nkey = normalize_service_key(raw)
        if not nkey:
            continue
        key = (cat_id, nkey)
        sid = int(s.get("id") or 0)
        row = dict(s)
        row["title"] = format_service_title_display(raw)
        if key not in best:
            best[key] = row
            continue
        ex = best[key]
        ex_id = int(ex.get("id") or 0)
        if sid and (not ex_id or sid < ex_id):
            best[key] = row
    return list(best.values())
