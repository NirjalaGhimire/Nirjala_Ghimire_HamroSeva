import os
from supabase import create_client, Client

# Supabase configuration from your dashboard
SUPABASE_URL = "https://srpvqzkkellawfolftnz.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNycHZxemtrZWxsYXdmb2xmdG56Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDA5OTE0NCwiZXhwIjoyMDg1Njc1MTQ0fQ.c48EeT8SWxpvfeNJeD_FXDHsDC3z0Ngye8zMRy--Ljg"

# Initialize Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def get_supabase_client() -> Client:
    return supabase

# Test the connection
def test_supabase_connection():
    try:
        # Test by querying the database info
        response = supabase.rpc('get_database_info').execute()
        print("✅ Supabase connection successful!")
        return True
    except Exception as e:
        print(f"❌ Supabase connection failed: {e}")
        return False

# Test by creating a simple table
def test_supabase_table_creation():
    try:
        # Create a test table to verify connection
        response = supabase.table('test_connection').select('*').limit(1).execute()
        print("✅ Supabase table access successful!")
        return True
    except Exception as e:
        print(f"❌ Supabase table access failed: {e}")
        # Try to create the table
        try:
            create_response = supabase.table('test_connection').insert({'id': 1, 'test': 'connection'}).execute()
            print("✅ Supabase table creation successful!")
            return True
        except Exception as create_error:
            print(f"❌ Supabase table creation failed: {create_error}")
            return False
