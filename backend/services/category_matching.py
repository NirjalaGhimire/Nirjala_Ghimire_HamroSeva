"""
Category / service title matching for provider discovery and catalog filtering.

CRITICAL: Never use a permissive default (e.g. return True for unknown categories).
That caused home trades (Carpenter, Plumber, Appliance Repair) to match *Events* and
backfill inserted seva_service rows under the wrong category_id.
"""

from __future__ import annotations

from .service_name_utils import normalize_service_key


def _lower(s: str | None) -> str:
    return (s or "").strip().lower()


def _profession_matches_home_services(text: str) -> bool:
    """Trades and domestic services — Home Services category only."""
    t = _lower(text)
    if not t:
        return False
    # Interior decorator / design belongs with home styling, not standalone event decorator
    if "interior" in t and "decor" in t:
        return True
    home_keywords = (
        "plumber",
        "plumbing",
        "carpenter",
        "carpentry",
        "electrician",
        "electrical",
        "electric repair",
        "appliance",
        "application repair",  # common typo → still home context
        "painter",
        "painting",
        "cleaner",
        "cleaning",
        "handyman",
        "home repair",
        "household",
        "hvac",
        "gardener",
        "gardener",
        "locksmith",
        "pest control",
        "plumber",
        "mobile repair",
        "ac repair",
        "plumber",
        "pipe",
        "woodwork",
        "tiling",
        "mason",
    )
    if any(k in t for k in home_keywords):
        return True
    # "Plumber , Electrician" style combined professions
    if "plumber" in t or "electrician" in t or "carpenter" in t:
        return True
    if "repair specialist" in t:
        if any(
            x in t
            for x in ("appliance", "electrical", "electric", "ac ", "mobile", "hvac")
        ):
            return True
    return False


def _profession_matches_events(text: str) -> bool:
    """Weddings, parties, AV, catering — Events category only."""
    t = _lower(text)
    if not t:
        return False
    # Hard exclude home trades (never Events)
    if _profession_matches_home_services(text):
        return False
    if any(
        x in t
        for x in (
            "tutor",
            "math",
            "education",
            "courier",
            "dietitian",
            "software",
            "nurse",
            "medical",
            "electrician",
            "plumber",
            "carpenter",
            "appliance",
        )
    ):
        return False

    event_keywords = (
        "dj",
        "disc jockey",
        "photographer",
        "photography",
        "videographer",
        "videography",
        "cinematography",
        "caterer",
        "catering",
        "event planner",
        "wedding planner",
        "party planner",
        "decorator",
        "event decor",
        "wedding",
        "banquet",
        "ceremony",
        "host",
        "emcee",
        "mc",
        "master of ceremony",
        "sound engineer",
        "lighting",
        "stage",
        "florist",
        "flower",
        "band",
        "entertainment",
        "coordination",
        "event management",
        "event staff",
    )
    if any(k in t for k in event_keywords):
        return True
    # Short titles
    if t.strip() in ("dj", "mc", "photographer", "videographer", "caterer", "decorator"):
        return True
    return False


def provider_profession_matches_category(provider_profession: str, category_name: str) -> bool:
    """
    True if the provider's profession string belongs in this category.
    Strict: unknown category names return False (no permissive default).
    """
    pro = _lower(provider_profession)
    cat = _lower(category_name)
    if not cat:
        return False

    # Healthcare
    if any(x in cat for x in ("health", "medical", "first aid", "clinic", "hospital")):
        return any(
            x in pro
            for x in (
                "first aid",
                "health",
                "nurse",
                "medical",
                "paramedic",
                "doctor",
                "care",
                "cpr",
                "training",
                "diet",
                "therapy",
                "massage",
            )
        )

    # Education
    if "education" in cat or "tutor" in cat:
        return any(
            x in pro
            for x in (
                "tutor",
                "education",
                "math",
                "teaching",
                "teacher",
                "language",
                "music teacher",
                "elderly",
            )
        )

    # Technology / IT
    if "tech" in cat or "technology" in cat:
        return any(
            x in pro
            for x in (
                "tech",
                "computer",
                "developer",
                "web",
                "it",
                "software",
                "support",
                "programming",
            )
        )

    # Transportation
    if "transport" in cat or "logistics" in cat:
        return any(
            x in pro
            for x in (
                "taxi",
                "driver",
                "courier",
                "delivery",
                "transport",
                "vehicle",
                "cargo",
            )
        )

    # Events (name contains "event")
    if "event" in cat:
        return _profession_matches_events(provider_profession)

    # Home Services — "Home", "Home Services", etc.
    if "home" in cat or "household" in cat:
        return _profession_matches_home_services(provider_profession)

    # Legacy single-word category slugs
    if "plumb" in cat:
        return "plumb" in pro
    if "electric" in cat and "home" not in cat:
        return "electric" in pro
    if "clean" in cat and "home" not in cat:
        return "clean" in pro
    if "carpent" in cat:
        return "carpent" in pro

    # Beauty & wellness
    if "beauty" in cat or "wellness" in cat or "salon" in cat:
        return any(x in pro for x in ("beauty", "salon", "massage", "hair", "wellness", "makeup", "spa"))

    # Fitness / yoga (if used as a category name)
    if any(x in cat for x in ("fitness", "yoga", "gym")):
        return any(
            x in pro
            for x in (
                "fitness",
                "yoga",
                "trainer",
                "gym",
                "pilates",
                "workout",
                "personal train",
            )
        )

    # Unknown / unmapped category — do not match everyone
    return False


def catalog_service_title_matches_category(service_title: str, category_name: str) -> bool:
    """
    Whether a catalog sub-service title (seva_service.title) belongs in this category.
    Used to filter GET /services/?category=&for_signup=1 so wrong DB rows do not appear.
    Same rules as profession matching, applied to the title string.
    """
    return provider_profession_matches_category(service_title, category_name)


def provider_profession_matches_service(provider_profession, service_title):
    """
    Legacy fuzzy matcher (substring + synonym groups).

    **Do not use for customer browse / Choose provider.** It incorrectly treated
    unrelated pairs as equivalent (e.g. "Electrician" with "Appliance Repair Specialist"
    because both matched the electric+repair word group).

    Prefer :func:`provider_profession_matches_catalog_service_title` for API filtering.
    """
    pro = normalize_service_key(provider_profession)
    svc = normalize_service_key(service_title)
    if not pro or not svc:
        return False
    if pro in svc or svc in pro:
        return True
    for word in pro.replace("-", " ").split():
        if len(word) >= 4 and word in svc:
            return True
    for word in svc.replace("-", " ").split():
        if len(word) >= 4 and word in pro:
            return True
    equivalent_groups = [
        ["electric", "electrical", "electrician", "repair"],
        ["plumb", "plumber", "plumbing"],
        ["carpent", "carpenter", "carpentry"],
        ["tutor", "education", "math", "teaching", "teacher"],
        ["clean", "cleaning"],
        ["beauty", "salon", "wellness", "hair", "massage"],
        ["tech", "computer", "web", "developer", "software", "support", "it"],
        ["first aid", "first-aid", "cpr", "healthcare", "health", "nurse", "medical"],
    ]
    for group in equivalent_groups:
        if any(g in pro for g in group) and any(g in svc for g in group):
            return True
    return False


def _profession_tokens_normalized(provider_profession: str | None) -> list[str]:
    """Split profession by comma; trim; normalize each non-empty segment to a comparison key."""
    raw = (provider_profession or "").strip()
    if not raw:
        return []
    parts = [p.strip() for p in raw.split(",")]
    keys = [normalize_service_key(p) for p in parts if p.strip()]
    # Preserve order, drop duplicates
    seen: set[str] = set()
    out: list[str] = []
    for k in keys:
        if k and k not in seen:
            seen.add(k)
            out.append(k)
    return out


def provider_profession_matches_catalog_service_title(
    provider_profession: str | None, service_title: str | None
) -> bool:
    """
    Strict match for browse: show a provider for a catalog sub-service only if their
    saved profession (comma-separated allowed) contains an **exact** normalized token
    equal to the catalog service title, or the whole profession string equals the title.

    Examples (normalized):
    - profession "Electrician" -> matches service "Electrician", not "Electrical Repair".
    - profession "plumber , Electrician" -> matches "Plumber" and "Electrician", not "Appliance Repair Specialist".
    """
    svc_key = normalize_service_key(service_title)
    if not svc_key:
        return False
    raw = (provider_profession or "").strip()
    if not raw:
        return False
    full_key = normalize_service_key(raw)
    if full_key == svc_key:
        return True
    tokens = _profession_tokens_normalized(raw)
    return svc_key in tokens
