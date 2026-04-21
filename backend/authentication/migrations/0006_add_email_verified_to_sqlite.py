from django.db import migrations


def add_column_if_missing(apps, schema_editor):
    """Keep local SQLite auth table compatible with current User model fields."""
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute("PRAGMA table_info(authentication_user)")
        cols = [row[1] for row in cursor.fetchall()]

        if 'email_verified' not in cols:
            cursor.execute(
                "ALTER TABLE authentication_user ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0"
            )

        # Existing admin users should stay usable after the column is introduced.
        cursor.execute("UPDATE authentication_user SET email_verified = 1 WHERE role = 'admin'")


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ('authentication', '0005_add_terms_columns_to_sqlite'),
    ]

    operations = [
        migrations.RunPython(add_column_if_missing, noop),
    ]
