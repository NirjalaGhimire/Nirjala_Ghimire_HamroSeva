# Add referral/loyalty columns to SQLite authentication_user so admin log (LogEntry → user) does not fail.
# Your app uses Supabase for auth; SQLite still has this table from initial migration and is used by Django admin log.

from django.db import migrations


def add_columns_if_missing(apps, schema_editor):
    """Add referral_code, loyalty_points, referred_by_id to authentication_user in default DB (SQLite)."""
    from django.db import connection
    with connection.cursor() as cursor:
        cursor.execute("PRAGMA table_info(authentication_user)")
        cols = [row[1] for row in cursor.fetchall()]
        if 'referral_code' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN referral_code VARCHAR(50) NULL")
        if 'loyalty_points' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN loyalty_points INTEGER NOT NULL DEFAULT 0")
        if 'referred_by_id' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN referred_by_id INTEGER NULL")


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False  # SQLite: commit each ALTER separately to avoid long transaction

    dependencies = [
        ('authentication', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(add_columns_if_missing, noop),
    ]
