from django.db import migrations


def add_columns_if_missing(apps, schema_editor):
    """
    Keep the local SQLite `authentication_user` table compatible with the fields
    used by the Django admin (even though the canonical data lives in Supabase).
    """
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute("PRAGMA table_info(authentication_user)")
        cols = [row[1] for row in cursor.fetchall()]

        # Terms & conditions acceptance tracking
        if 'terms_accepted' not in cols:
            cursor.execute(
                "ALTER TABLE authentication_user ADD COLUMN terms_accepted INTEGER NOT NULL DEFAULT 0"
            )
        if 'terms_accepted_at' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN terms_accepted_at DATETIME NULL")


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ('authentication', '0004_add_provider_verification_columns_to_sqlite'),
    ]

    operations = [
        migrations.RunPython(add_columns_if_missing, noop),
    ]

