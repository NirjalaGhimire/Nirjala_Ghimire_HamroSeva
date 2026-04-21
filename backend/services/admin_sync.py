from django.core.cache import cache
from django.core.management import call_command


SYNC_CACHE_KEY = 'admin_supabase_sync_last_epoch'
SYNC_TTL_SECONDS = 20


def ensure_admin_data_synced():
    """Throttle expensive sync commands while keeping admin pages fresh."""
    if cache.get(SYNC_CACHE_KEY):
        return
    try:
        call_command('sync_supabase_users', verbosity=0)
    except Exception:
        pass
    try:
        call_command('sync_supabase_all', verbosity=0)
    except Exception:
        pass
    cache.set(SYNC_CACHE_KEY, 1, timeout=SYNC_TTL_SECONDS)

