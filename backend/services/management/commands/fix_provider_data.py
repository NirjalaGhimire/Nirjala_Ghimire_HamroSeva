"""
Management command to audit and fix verification status and location data issues.

Usage:
    python manage.py fix_provider_data --audit  # Show issues
    python manage.py fix_provider_data --fix     # Fix issues
    python manage.py fix_provider_data --list    # List affected providers
"""

from django.core.management.base import BaseCommand
from authentication.models import User
from supabase_config import get_supabase_client


class Command(BaseCommand):
    help = 'Fix verification status and location data issues for providers'

    def add_arguments(self, parser):
        parser.add_argument(
            '--audit',
            action='store_true',
            help='Show verification status and location issues without fixing',
        )
        parser.add_argument(
            '--fix',
            action='store_true',
            help='Fix verification status and location issues',
        )
        parser.add_argument(
            '--list',
            action='store_true',
            help='List all providers with issues',
        )

    def handle(self, *args, **options):
        if options['audit']:
            self.audit_data()
        elif options['fix']:
            self.fix_data()
        elif options['list']:
            self.list_affected_providers()
        else:
            self.stdout.write(self.style.WARNING('Use --audit, --fix, or --list'))

    def audit_data(self):
        """Show issues without fixing"""
        self.stdout.write(self.style.SUCCESS('=== VERIFICATION STATUS & LOCATION AUDIT ===\n'))
        
        supabase = get_supabase_client()
        
        # Get all providers
        try:
            response = supabase.table('seva_auth_user').select('*').in_(
                'role', ['provider', 'prov']
            ).execute()
            providers = response.data or []
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error fetching providers: {e}'))
            return

        # Statistics
        total_providers = len(providers)
        missing_location = 0
        invalid_status = 0
        verified_count = 0
        pending_count = 0
        unverified_count = 0
        rejected_count = 0

        self.stdout.write(f'Total Providers: {total_providers}\n')

        for provider in providers:
            status = (provider.get('verification_status') or 'unverified').lower().strip()
            district = (provider.get('district') or '').strip()
            city = (provider.get('city') or '').strip()
            username = provider.get('username') or f"ID:{provider.get('id')}"

            # Check for issues
            has_location_issue = not district or not city
            has_status_issue = status not in ('approved', 'pending', 'rejected', 'unverified')

            if has_location_issue:
                missing_location += 1
                self.stdout.write(
                    self.style.WARNING(
                        f'  ⚠️  {username}: Missing location '
                        f'(District: {district or "EMPTY"}, City: {city or "EMPTY"})'
                    )
                )

            if has_status_issue:
                invalid_status += 1
                self.stdout.write(
                    self.style.ERROR(
                        f'  ❌ {username}: Invalid status "{status}" (must be: '
                        'approved, pending, rejected, unverified)'
                    )
                )

            # Count by status
            if status == 'approved':
                verified_count += 1
            elif status == 'pending':
                pending_count += 1
            elif status == 'rejected':
                rejected_count += 1
            else:
                unverified_count += 1

        self.stdout.write(f'\n=== SUMMARY ===')
        self.stdout.write(f'Verified (approved):     {verified_count}')
        self.stdout.write(f'Pending:                 {pending_count}')
        self.stdout.write(f'Rejected:                {rejected_count}')
        self.stdout.write(f'Unverified:              {unverified_count}')
        self.stdout.write(f'Missing Location Data:   {missing_location}')
        self.stdout.write(f'Invalid Status Values:   {invalid_status}')

    def fix_data(self):
        """Fix verification status and location issues"""
        self.stdout.write(self.style.SUCCESS('=== FIXING VERIFICATION STATUS & LOCATION DATA ===\n'))
        
        supabase = get_supabase_client()
        fixed_count = 0

        try:
            response = supabase.table('seva_auth_user').select('*').in_(
                'role', ['provider', 'prov']
            ).execute()
            providers = response.data or []
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error fetching providers: {e}'))
            return

        for provider in providers:
            pid = provider.get('id')
            status = (provider.get('verification_status') or 'unverified').lower().strip()
            needs_fix = False
            fix_data = {}

            # Fix invalid status
            if status not in ('approved', 'pending', 'rejected', 'unverified'):
                self.stdout.write(
                    self.style.WARNING(
                        f'Fixing {provider.get("username")}: Invalid status "{status}" -> "unverified"'
                    )
                )
                fix_data['verification_status'] = 'unverified'
                needs_fix = True

            if fix_data:
                try:
                    supabase.table('seva_auth_user').update(fix_data).eq('id', pid).execute()
                    fixed_count += 1
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(
                            f'Error fixing provider {pid}: {e}'
                        )
                    )

        self.stdout.write(self.style.SUCCESS(f'\n✅ Fixed {fixed_count} provider records'))
        self.stdout.write(self.style.WARNING('Note: Providers missing location data need manual updates'))

    def list_affected_providers(self):
        """List providers with issues"""
        self.stdout.write(self.style.SUCCESS('=== PROVIDERS WITH ISSUES ===\n'))
        
        supabase = get_supabase_client()

        try:
            response = supabase.table('seva_auth_user').select('*').in_(
                'role', ['provider', 'prov']
            ).execute()
            providers = response.data or []
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error fetching providers: {e}'))
            return

        affected = []
        for provider in providers:
            status = (provider.get('verification_status') or '').lower().strip()
            district = (provider.get('district') or '').strip()
            city = (provider.get('city') or '').strip()

            if status not in ('approved', 'pending', 'rejected', 'unverified') or not district or not city:
                affected.append({
                    'id': provider.get('id'),
                    'username': provider.get('username'),
                    'status': status or 'INVALID',
                    'district': district or 'MISSING',
                    'city': city or 'MISSING',
                    'profession': provider.get('profession') or 'N/A',
                })

        if affected:
            self.stdout.write(f'Found {len(affected)} providers with issues:\n')
            for prov in sorted(affected, key=lambda x: x['username']):
                self.stdout.write(
                    f"  ID: {prov['id']} | {prov['username']} | Status: {prov['status']} | "
                    f"Location: {prov['city']}, {prov['district']} | Profession: {prov['profession']}"
                )
        else:
            self.stdout.write(self.style.SUCCESS('✅ No providers with issues found!'))
