import json
from datetime import datetime, timezone

from django.db import connection

from supabase_config import get_supabase_client


SUPABASE_TABLE = 'seva_service_category_request'
LOCAL_TABLE = 'seva_service_category_request'


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _ensure_local_table():
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {LOCAL_TABLE} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_id INTEGER NOT NULL,
                requested_title TEXT NOT NULL,
                description TEXT,
                address TEXT,
                latitude REAL,
                longitude REAL,
                image_urls TEXT,
                status TEXT NOT NULL DEFAULT 'pending',
                admin_review_note TEXT,
                reviewed_by INTEGER,
                reviewed_at TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
def _mirror_request_to_local(row):
    _ensure_local_table()
    created_at = row.get('created_at') or _now_iso()
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            INSERT OR REPLACE INTO {LOCAL_TABLE}
                (id, customer_id, requested_title, description, address, latitude, longitude,
                 image_urls, status, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            [
                row.get('id'),
                row.get('customer_id'),
                row.get('requested_title'),
                row.get('description'),
                row.get('address'),
                row.get('latitude'),
                row.get('longitude'),
                row.get('image_urls'),
                row.get('status') or 'pending',
                created_at,
            ],
        )




def _is_missing_table_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return 'pgrst205' in msg or 'does not exist' in msg or 'relation' in msg


def create_request(payload):
    supabase = get_supabase_client()
    try:
        inserted = supabase.table(SUPABASE_TABLE).insert(payload).execute()
        row = (inserted.data or [{}])[0] if inserted.data else {}
        row['storage'] = 'supabase'
        try:
            _mirror_request_to_local(row)
        except Exception:
            # Mirror failures should not block the primary write.
            pass
        return row
    except Exception as exc:
        if not _is_missing_table_error(exc):
            raise

    _ensure_local_table()
    created_at = _now_iso()
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO {LOCAL_TABLE}
                (customer_id, requested_title, description, address, latitude, longitude, image_urls, status, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            [
                payload.get('customer_id'),
                payload.get('requested_title'),
                payload.get('description'),
                payload.get('address'),
                payload.get('latitude'),
                payload.get('longitude'),
                payload.get('image_urls'),
                payload.get('status') or 'pending',
                created_at,
            ],
        )


def _update_local_request(request_id, payload):
    _ensure_local_table()
    set_sql = ['status = %s']
    params = [payload.get('status')]
    params.append(int(request_id))
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE {LOCAL_TABLE}
            SET {', '.join(set_sql)}
            WHERE id = %s
            """,
            params,
        )
        request_id = cursor.lastrowid
    return {
        'id': request_id,
        'customer_id': payload.get('customer_id'),
        'requested_title': payload.get('requested_title'),
        'description': payload.get('description'),
        'address': payload.get('address'),
        'latitude': payload.get('latitude'),
        'longitude': payload.get('longitude'),
        'image_urls': payload.get('image_urls'),
        'status': payload.get('status') or 'pending',
        'created_at': created_at,
        'storage': 'local_fallback',
    }


def list_requests(status_filter=None, limit=200):
    supabase = get_supabase_client()
    try:
        query = supabase.table(SUPABASE_TABLE).select('*').order('created_at', desc=True).limit(limit)
        if status_filter:
            query = query.eq('status', status_filter)
        result = query.execute()
        rows = list(result.data or [])
        for row in rows:
            row['storage'] = 'supabase'
        return rows
    except Exception as exc:
        if not _is_missing_table_error(exc):
            raise

    _ensure_local_table()
    sql = f"""
         SELECT id, customer_id, requested_title, description, address, latitude, longitude,
             image_urls, status, created_at
        FROM {LOCAL_TABLE}
    """
    params = []
    if status_filter:
        sql += ' WHERE status = %s'
        params.append(status_filter)
    sql += ' ORDER BY datetime(created_at) DESC LIMIT %s'
    params.append(limit)

    with connection.cursor() as cursor:
        cursor.execute(sql, params)
        rows = cursor.fetchall()

    out = []
    for row in rows:
        out.append(
            {
                'id': row[0],
                'customer_id': row[1],
                'requested_title': row[2],
                'description': row[3],
                'address': row[4],
                'latitude': row[5],
                'longitude': row[6],
                'image_urls': row[7],
                'status': row[8],
                'created_at': row[9],
                'storage': 'local_fallback',
            }
        )
    return out


def review_request(request_id, new_status, reviewed_by, admin_note=None):
    if new_status not in {'approved', 'rejected'}:
        raise ValueError('status must be approved or rejected')

    supabase = get_supabase_client()
    payload = {
        'status': new_status,
        'reviewed_by': int(reviewed_by),
        'reviewed_at': _now_iso(),
    }
    if admin_note:
        payload['admin_review_note'] = admin_note[:1000]

    try:
        updated = supabase.table(SUPABASE_TABLE).update(payload).eq('id', int(request_id)).execute()
        data = updated.data or []
        if not data:
            return None
        row = data[0]
        row['storage'] = 'supabase'
        try:
            _update_local_request(int(request_id), payload)
        except Exception:
            # Keep the primary update even if the mirror write fails.
            pass
        return row
    except Exception as exc:
        if not _is_missing_table_error(exc):
            raise

    _ensure_local_table()
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE {LOCAL_TABLE}
            SET status = %s, admin_review_note = %s, reviewed_by = %s, reviewed_at = %s
            WHERE id = %s
            """,
            [
                new_status,
                (admin_note or None),
                int(reviewed_by),
                _now_iso(),
                int(request_id),
            ],
        )
        if cursor.rowcount == 0:
            return None

    rows = list_requests(limit=500)
    for row in rows:
        if int(row.get('id') or 0) == int(request_id):
            return row
    return None


def parse_image_urls(value):
    if not value:
        return []
    if isinstance(value, list):
        return [str(v) for v in value if v]
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return []
        if raw.startswith('['):
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, list):
                    return [str(v) for v in parsed if v]
            except Exception:
                pass
        return [raw]
    return []