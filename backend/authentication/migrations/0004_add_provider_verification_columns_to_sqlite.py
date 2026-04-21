from django.db import migrations


def add_columns_if_missing(apps, schema_editor):
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute("PRAGMA table_info(authentication_user)")
        cols = [row[1] for row in cursor.fetchall()]

        if 'verification_status' not in cols:
            cursor.execute(
                "ALTER TABLE authentication_user ADD COLUMN verification_status VARCHAR(30) NOT NULL DEFAULT 'approved'"
            )
        if 'rejection_reason' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN rejection_reason TEXT NULL")
        if 'is_active_provider' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN is_active_provider INTEGER NOT NULL DEFAULT 0")
        if 'submitted_at' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN submitted_at DATETIME NULL")
        if 'reviewed_at' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN reviewed_at DATETIME NULL")
        if 'reviewed_by' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN reviewed_by INTEGER NULL")


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ('authentication', '0003_add_profile_columns_to_sqlite'),
    ]

    operations = [
        migrations.RunPython(add_columns_if_missing, noop),
    ]

