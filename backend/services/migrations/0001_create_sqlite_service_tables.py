# Create SQLite tables for admin (seva_*). Real data lives in Supabase; these allow admin list views to load without "no such table".

from django.db import migrations, connection


def create_tables(apps, schema_editor):
    with connection.cursor() as c:
        # seva_servicecategory
        c.execute("""
            CREATE TABLE IF NOT EXISTS seva_servicecategory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name VARCHAR(100) NOT NULL,
                description TEXT,
                icon VARCHAR(50),
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)
        # seva_service (provider_id -> authentication_user, category_id -> seva_servicecategory)
        c.execute("""
            CREATE TABLE IF NOT EXISTS seva_service (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                provider_id INTEGER NOT NULL,
                category_id INTEGER NOT NULL,
                title VARCHAR(200) NOT NULL,
                description TEXT NOT NULL,
                price DECIMAL(10,2) NOT NULL,
                duration_minutes INTEGER NOT NULL,
                location VARCHAR(255) NOT NULL,
                status VARCHAR(20) NOT NULL DEFAULT 'active',
                image_url VARCHAR(200),
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)
        # seva_booking
        c.execute("""
            CREATE TABLE IF NOT EXISTS seva_booking (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_id INTEGER NOT NULL,
                service_id INTEGER NOT NULL,
                booking_date DATE NOT NULL,
                booking_time TIME NOT NULL,
                status VARCHAR(20) NOT NULL DEFAULT 'pending',
                notes TEXT,
                total_amount DECIMAL(10,2) NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)
        # seva_review
        c.execute("""
            CREATE TABLE IF NOT EXISTS seva_review (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                booking_id INTEGER NOT NULL UNIQUE,
                customer_id INTEGER NOT NULL,
                provider_id INTEGER NOT NULL,
                rating INTEGER NOT NULL,
                comment TEXT NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    atomic = False
    initial = True
    dependencies = [
        ('authentication', '0002_add_referral_columns_to_sqlite'),
    ]
    operations = [
        migrations.RunPython(create_tables, noop),
    ]
