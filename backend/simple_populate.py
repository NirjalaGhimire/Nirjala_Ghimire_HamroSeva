#!/usr/bin/env python
"""
Simple script to populate Supabase with sample data using existing tables
"""

import os
import sys
from datetime import datetime, date, time
from supabase_config import get_supabase_client

def create_sample_providers():
    """Create sample provider users"""
    supabase = get_supabase_client()
    
    providers = [
        {
            'username': 'provider1',
            'email': 'provider1@example.com',
            'password': 'provider123',
            'role': 'provider',
            'profession': 'Electrician & IT Support',
            'phone': '9841000001'
        },
        {
            'username': 'provider2',
            'email': 'provider2@example.com',
            'password': 'provider123',
            'role': 'provider',
            'profession': 'Beautician & Salon Expert',
            'phone': '9841000002'
        },
        {
            'username': 'provider3',
            'email': 'provider3@example.com',
            'password': 'provider123',
            'role': 'provider',
            'profession': 'Mathematics Tutor',
            'phone': '9841000003'
        }
    ]
    
    try:
        # Check if providers already exist
        existing = supabase.table('seva_auth_user').select('*').eq('role', 'provider').execute()
        if existing.data:
            print(f"✅ Found {len(existing.data)} existing providers")
            return existing.data
        
        # Create new providers
        response = supabase.table('seva_auth_user').insert(providers).execute()
        print(f"✅ Created {len(response.data)} sample providers")
        return response.data
    except Exception as e:
        print(f"❌ Error creating providers: {e}")
        return []

def create_sample_customers():
    """Create sample customer users"""
    supabase = get_supabase_client()
    
    customers = [
        {
            'username': 'customer1',
            'email': 'customer1@example.com',
            'password': 'customer123',
            'role': 'customer',
            'profession': '',
            'phone': '9842000001'
        },
        {
            'username': 'customer2',
            'email': 'customer2@example.com',
            'password': 'customer123',
            'role': 'customer',
            'profession': '',
            'phone': '9842000002'
        }
    ]
    
    try:
        # Check if customers already exist
        existing = supabase.table('seva_auth_user').select('*').eq('role', 'customer').execute()
        if existing.data:
            print(f"✅ Found {len(existing.data)} existing customers")
            return existing.data
        
        # Create new customers
        response = supabase.table('seva_auth_user').insert(customers).execute()
        print(f"✅ Created {len(response.data)} sample customers")
        return response.data
    except Exception as e:
        print(f"❌ Error creating customers: {e}")
        return []

def create_manual_service_data():
    """Create service data as a simple approach"""
    supabase = get_supabase_client()
    
    # Since we can't create tables easily, let's create a simple JSON response
    # that the frontend can use for demo purposes
    
    services_data = [
        {
            'id': 1,
            'provider_id': 1,
            'provider_name': 'provider1',
            'provider_email': 'provider1@example.com',
            'category': 'Home Services',
            'title': 'Home Cleaning Service',
            'description': 'Professional home cleaning with eco-friendly products. Deep cleaning available for all rooms.',
            'price': '1500.00',
            'duration_minutes': 120,
            'location': 'Kathmandu',
            'status': 'active',
            'image_url': 'https://picsum.photos/seed/cleaning/400/300.jpg'
        },
        {
            'id': 2,
            'provider_id': 1,
            'provider_name': 'provider1',
            'provider_email': 'provider1@example.com',
            'category': 'Technology',
            'title': 'Computer Repair',
            'description': 'Expert computer repair for all brands. Hardware and software issues resolved.',
            'price': '1200.00',
            'duration_minutes': 90,
            'location': 'Patan',
            'status': 'active',
            'image_url': 'https://picsum.photos/seed/computer/400/300.jpg'
        },
        {
            'id': 3,
            'provider_id': 2,
            'provider_name': 'provider2',
            'provider_email': 'provider2@example.com',
            'category': 'Beauty & Wellness',
            'title': 'Hair Styling & Makeup',
            'description': 'Professional hair styling and makeup services for all occasions.',
            'price': '2000.00',
            'duration_minutes': 150,
            'location': 'Lalitpur',
            'status': 'active',
            'image_url': 'https://picsum.photos/seed/beauty/400/300.jpg'
        },
        {
            'id': 4,
            'provider_id': 2,
            'provider_name': 'provider2',
            'provider_email': 'provider2@example.com',
            'category': 'Beauty & Wellness',
            'title': 'Massage Therapy',
            'description': 'Relaxing full-body massage with essential oils and professional techniques.',
            'price': '2500.00',
            'duration_minutes': 60,
            'location': 'Kathmandu',
            'status': 'active',
            'image_url': 'https://picsum.photos/seed/massage/400/300.jpg'
        },
        {
            'id': 5,
            'provider_id': 3,
            'provider_name': 'provider3',
            'provider_email': 'provider3@example.com',
            'category': 'Education',
            'title': 'Mathematics Tutoring',
            'description': 'Expert math tutoring for school and college students. All levels covered.',
            'price': '1000.00',
            'duration_minutes': 60,
            'location': 'Online',
            'status': 'active',
            'image_url': 'https://picsum.photos/seed/tutoring/400/300.jpg'
        }
    ]
    
    return services_data

def update_backend_with_mock_data():
    """Update backend views to return mock data when tables don't exist"""
    print("📝 Backend will use mock data for services and bookings")
    print("🔧 To use real database tables, create them in Supabase manually")

def main():
    """Main function to populate data"""
    print("🚀 Setting up Hamro Sewa sample data...")
    
    # Create users
    providers = create_sample_providers()
    customers = create_sample_customers()
    
    # Get service data (mock for now)
    services = create_manual_service_data()
    
    print("\n✅ Setup completed!")
    print(f"📊 Summary:")
    print(f"   - Providers: {len(providers) if providers else 0}")
    print(f"   - Customers: {len(customers) if customers else 0}")
    print(f"   - Services (Mock): {len(services)}")
    
    print("\n👤 Login Credentials:")
    print("   Existing:")
    print("     - testuser2 / testpass123 (customer)")
    print("   New Providers:")
    print("     - provider1 / provider123")
    print("     - provider2 / provider123") 
    print("     - provider3 / provider123")
    print("   New Customers:")
    print("     - customer1 / customer123")
    print("     - customer2 / customer123")
    
    print("\n🔧 Note: Services will use mock data until Supabase tables are created")
    
    # Save services data to a file for reference
    with open('mock_services.json', 'w') as f:
        import json
        json.dump(services, f, indent=2)
    print("📄 Mock services data saved to mock_services.json")

if __name__ == "__main__":
    main()
