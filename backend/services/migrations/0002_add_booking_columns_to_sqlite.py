from django.db import migrations


def add_booking_columns_if_missing(apps, schema_editor):
    """Keep SQLite seva_booking schema aligned for Django admin pages."""
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute("PRAGMA table_info(seva_booking)")
        cols = [row[1] for row in cursor.fetchall()]

        if 'quoted_price' not in cols:
            cursor.execute("ALTER TABLE seva_booking ADD COLUMN quoted_price DECIMAL(10,2) NULL")
        if 'request_image_url' not in cols:
            cursor.execute("ALTER TABLE seva_booking ADD COLUMN request_image_url TEXT NULL")
        if 'address' not in cols:
            cursor.execute("ALTER TABLE seva_booking ADD COLUMN address TEXT NULL")
        if 'latitude' not in cols:
            cursor.execute("ALTER TABLE seva_booking ADD COLUMN latitude DECIMAL(10,8) NULL")
        if 'longitude' not in cols:
            cursor.execute("ALTER TABLE seva_booking ADD COLUMN longitude DECIMAL(11,8) NULL")


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ('services', '0001_create_sqlite_service_tables'),
    ]

    operations = [
        migrations.RunPython(add_booking_columns_if_missing, noop),
    ]

