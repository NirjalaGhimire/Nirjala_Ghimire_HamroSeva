#!/usr/bin/env python
"""
Populate Supabase tables with real data for Hamro Sewa
"""

import os
import sys
from datetime import datetime, date, time
from supabase_config import get_supabase_client

def populate_service_categories():
    """Populate service categories table"""
    supabase = get_supabase_client()
    
    categories = [
        {'name': 'Home Services', 'description': 'Cleaning, repair, maintenance', 'icon': '🏠'},
        {'name': 'Beauty & Wellness', 'description': 'Salon, spa, fitness', 'icon': '💄'},
        {'name': 'Education', 'description': 'Tutoring, training, courses', 'icon': '📚'},
        {'name': 'Technology', 'description': 'IT support, web development', 'icon': '💻'},
        {'name': 'Transportation', 'description': 'Moving, delivery, logistics', 'icon': '🚗'},
        {'name': 'Healthcare', 'description': 'Medical, dental, therapy', 'icon': '🏥'},
        {'name': 'Events', 'description': 'Photography, catering, decoration', 'icon': '🎉'},
    ]
    
    try:
        response = supabase.table('seva_servicecategory').insert(categories).execute()
        print(f"✅ Created {len(response.data)} service categories")
        return response.data
    except Exception as e:
        print(f"❌ Error creating categories: {e}")
        return []

def populate_services():
    """Populate services table"""
    supabase = get_supabase_client()
    
    # Get categories
    categories_response = supabase.table('seva_servicecategory').select('*').execute()
    categories = {cat['name']: cat['id'] for cat in categories_response.data}
    
    # Get providers
    providers_response = supabase.table('seva_auth_user').select('*').eq('role', 'provider').execute()
    providers = providers_response.data
    
    if not providers:
        print("❌ No providers found!")
        return []
    
    services = []
    
    # Home Services
    if 'Home Services' in categories:
        services.extend([
            {
                'provider_id': providers[0]['id'],
                'category_id': categories['Home Services'],
                'title': 'Home Cleaning Service',
                'description': 'Professional home cleaning with eco-friendly products. Deep cleaning available.',
                'price': 1500.00,
                'duration_minutes': 120,
                'location': 'Kathmandu',
                'status': 'active',
                'image_url': 'https://picsum.photos/seed/cleaning/400/300.jpg'
            },
            {
                'provider_id': providers[0]['id'],
                'category_id': categories['Home Services'],
                'title': 'Electrical Repair',
                'description': 'Expert electrical repairs and installations for residential properties.',
                'price': 800.00,
                'duration_minutes': 90,
                'location': 'Patan',
                'status': 'active',
                'image_url': 'https://picsum.photos/seed/electrical/400/300.jpg'
            }
        ])
    
    # Beauty & Wellness
    if 'Beauty & Wellness' in categories:
        services.extend([
            {
                'provider_id': providers[1]['id'] if len(providers) > 1 else providers[0]['id'],
                'category_id': categories['Beauty & Wellness'],
                'title': 'Hair Styling & Makeup',
                'description': 'Professional hair styling and makeup services for all occasions.',
                'price': 2000.00,
                'duration_minutes': 150,
                'location': 'Lalitpur',
                'status': 'active',
                'image_url': 'https://picsum.photos/seed/beauty/400/300.jpg'
            },
            {
                'provider_id': providers[1]['id'] if len(providers) > 1 else providers[0]['id'],
                'category_id': categories['Beauty & Wellness'],
                'title': 'Massage Therapy',
                'description': 'Relaxing full-body massage with essential oils.',
                'price': 2500.00,
                'duration_minutes': 60,
                'location': 'Kathmandu',
                'status': 'active',
                'image_url': 'https://picsum.photos/seed/massage/400/300.jpg'
            }
        ])
    
    # Education
    if 'Education' in categories:
        services.extend([
            {
                'provider_id': providers[0]['id'],
                'category_id': categories['Education'],
                'title': 'Mathematics Tutoring',
                'description': 'Expert math tutoring for school and college students.',
                'price': 1000.00,
                'duration_minutes': 60,
                'location': 'Online',
                'status': 'active',
                'image_url': 'https://picsum.photos/seed/tutoring/400/300.jpg'
            }
        ])
    
    # Technology
    if 'Technology' in categories:
        services.extend([
            {
                'provider_id': providers[0]['id'],
                'category_id': categories['Technology'],
                'title': 'Web Development',
                'description': 'Custom website development using modern technologies.',
                'price': 15000.00,
                'duration_minutes': 480,
                'location': 'Remote',
                'status': 'active',
                'image_url': 'https://picsum.photos/seed/webdev/400/300.jpg'
            },
            {
                'provider_id': providers[0]['id'],
                'category_id': categories['Technology'],
                'title': 'Computer Repair',
                'description': 'Hardware and software repair for all computer brands.',
                'price': 1200.00,
                'duration_minutes': 120,
                'location': 'Kathmandu',
                'status': 'active',
                'image_url': 'https://picsum.photos/seed/computer/400/300.jpg'
            }
        ])
    
    try:
        response = supabase.table('seva_service').insert(services).execute()
        print(f"✅ Created {len(response.data)} services")
        return response.data
    except Exception as e:
        print(f"❌ Error creating services: {e}")
        return []

def populate_sample_bookings():
    """Populate bookings table with sample data"""
    supabase = get_supabase_client()
    
    # Get customers and services
    customers_response = supabase.table('seva_auth_user').select('*').eq('role', 'customer').execute()
    services_response = supabase.table('seva_service').select('*').execute()
    
    customers = customers_response.data
    services = services_response.data
    
    if not customers or not services:
        print("❌ No customers or services found for bookings")
        return []
    
    bookings = []
    
    # Create sample bookings
    for i, customer in enumerate(customers[:3]):  # First 3 customers
        for j, service in enumerate(services[:2]):  # 2 bookings per customer
            booking_date = date(2025, 1, 15 + i * 7)
            booking_time = time(10 + j * 2, 0)
            
            status = ['pending', 'confirmed', 'completed'][i % 3]
            
            bookings.append({
                'customer_id': customer['id'],
                'service_id': service['id'],
                'booking_date': booking_date.isoformat(),
                'booking_time': booking_time.isoformat(),
                'status': status,
                'notes': f'Sample booking {i+1}-{j+1}',
                'total_amount': float(service['price'])
            })
    
    try:
        response = supabase.table('seva_booking').insert(bookings).execute()
        print(f"✅ Created {len(response.data)} bookings")
        return response.data
    except Exception as e:
        print(f"❌ Error creating bookings: {e}")
        return []

def test_api_endpoints():
    """Test that the API endpoints work with real data"""
    print("\n🧪 Testing API endpoints...")
    
    # Test categories
    try:
        import requests
        response = requests.get('http://127.0.0.1:8000/api/categories/')
        if response.status_code == 200:
            print("✅ Categories API working")
        else:
            print(f"❌ Categories API failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Categories API error: {e}")
    
    # Test services
    try:
        response = requests.get('http://127.0.0.1:8000/api/services/')
        if response.status_code == 200:
            print("✅ Services API working")
        else:
            print(f"❌ Services API failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Services API error: {e}")

def main():
    """Main function to populate all tables"""
    print("🚀 Populating Supabase tables with real data...")
    
    # Populate tables in order
    categories = populate_service_categories()
    services = populate_services()
    bookings = populate_sample_bookings()
    
    print("\n✅ Database population completed!")
    print(f"📊 Summary:")
    print(f"   - Service Categories: {len(categories) if categories else 0}")
    print(f"   - Services: {len(services) if services else 0}")
    print(f"   - Bookings: {len(bookings) if bookings else 0}")
    
    print("\n👤 Login Credentials:")
    print("   Customers:")
    print("     - testuser2 / testpass123")
    print("   Providers:")
    print("     - provider1 / provider123")
    print("     - provider2 / provider123")
    
    # Test APIs
    test_api_endpoints()
    
    print("\n🎉 Your Hamro Sewa booking system is now ready with real data!")

if __name__ == "__main__":
    main()
