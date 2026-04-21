from django.db import migrations


def create_service_category_request_table(apps, schema_editor):
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute("PRAGMA table_info(seva_service_category_request)")
        existing_cols = [row[1] for row in cursor.fetchall()]

        if not existing_cols:
            cursor.execute(
                """
                CREATE TABLE seva_service_category_request (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    customer_id INTEGER NOT NULL,
                    requested_title VARCHAR(500) NOT NULL,
                    description TEXT NULL,
                    address VARCHAR(1000) NULL,
                    latitude DECIMAL(10,8) NULL,
                    longitude DECIMAL(11,8) NULL,
                    image_urls TEXT NULL,
                    status VARCHAR(32) NOT NULL DEFAULT 'pending',
                    created_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP
                )
                """
            )

            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_svc_cat_req_customer ON seva_service_category_request(customer_id)"
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_svc_cat_req_status ON seva_service_category_request(status)"
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_svc_cat_req_created ON seva_service_category_request(created_at DESC)"
            )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ('services', '0002_add_booking_columns_to_sqlite'),
    ]

    operations = [
        migrations.RunPython(create_service_category_request_table, noop),
    ]