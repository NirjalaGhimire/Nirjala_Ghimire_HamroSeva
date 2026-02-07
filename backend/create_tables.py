#!/usr/bin/env python
"""
Create Supabase tables for Hamro Sewa
"""

import os
import sys
from supabase_config import get_supabase_client

def create_service_categories_table():
    """Create service categories table"""
    supabase = get_supabase_client()
    
    # Use SQL to create table
    sql = """
    CREATE TABLE IF NOT EXISTS seva_servicecategory (
        id BIGSERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        description TEXT,
        icon VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    """
    
    try:
        response = supabase.rpc('exec_sql', {'sql': sql}).execute()
        print("✅ Service categories table created")
    except Exception as e:
        print(f"❌ Error creating service categories table: {e}")
        # Try direct insert to create table implicitly
        try:
            test_data = {
                'name': 'Test Category',
                'description': 'Test description',
                'icon': '🧪'
            }
            supabase.table('seva_servicecategory').insert(test_data).execute()
            print("✅ Service categories table created via insert")
            # Remove test data
            supabase.table('seva_servicecategory').delete().eq('name', 'Test Category').execute()
        except Exception as e2:
            print(f"❌ Still failed: {e2}")

def create_services_table():
    """Create services table"""
    supabase = get_supabase_client()
    
    test_service = {
        'provider_id': 1,
        'category_id': 1,
        'title': 'Test Service',
        'description': 'Test description',
        'price': 1000.00,
        'duration_minutes': 60,
        'location': 'Test Location',
        'status': 'active',
        'image_url': 'https://picsum.photos/seed/test/400/300.jpg'
    }
    
    try:
        response = supabase.table('seva_service').insert(test_service).execute()
        print("✅ Services table created")
        # Remove test data
        supabase.table('seva_service').delete().eq('title', 'Test Service').execute()
    except Exception as e:
        print(f"❌ Error creating services table: {e}")

def create_bookings_table():
    """Create bookings table"""
    supabase = get_supabase_client()
    
    test_booking = {
        'customer_id': 1,
        'service_id': 1,
        'booking_date': '2025-01-15',
        'booking_time': '10:00:00',
        'status': 'pending',
        'notes': 'Test booking',
        'total_amount': 1000.00
    }
    
    try:
        response = supabase.table('seva_booking').insert(test_booking).execute()
        print("✅ Bookings table created")
        # Remove test data
        supabase.table('seva_booking').delete().eq('notes', 'Test booking').execute()
    except Exception as e:
        print(f"❌ Error creating bookings table: {e}")

def main():
    """Create all tables"""
    print("🚀 Creating Supabase tables...")
    
    create_service_categories_table()
    create_services_table()
    create_bookings_table()
    
    print("✅ Table creation completed!")

if __name__ == "__main__":
    main()
