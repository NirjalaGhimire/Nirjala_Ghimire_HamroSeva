from django.db import migrations


def add_columns_if_missing(apps, schema_editor):
    """Keep SQLite auth table in sync enough for Django admin queries."""
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute("PRAGMA table_info(authentication_user)")
        cols = [row[1] for row in cursor.fetchall()]

        if 'qualification' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN qualification TEXT NULL")
        if 'profile_image_url' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN profile_image_url TEXT NULL")
        if 'district' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN district VARCHAR(120) NULL")
        if 'city' not in cols:
            cursor.execute("ALTER TABLE authentication_user ADD COLUMN city VARCHAR(120) NULL")


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ('authentication', '0002_add_referral_columns_to_sqlite'),
    ]

    operations = [
        migrations.RunPython(add_columns_if_missing, noop),
    ]

