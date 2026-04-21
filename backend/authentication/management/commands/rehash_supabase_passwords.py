"""
Re-hash Supabase passwords stored in `seva_auth_user` so they are never kept as plain text.

Use this only if your existing Supabase rows currently store plain passwords
(for example, created by scripts like `backend/simple_populate.py`).

This command detects "looks like a Django hash" via prefix and re-hashes everything else.
"""

import re

from django.contrib.auth.hashers import make_password
from django.core.management.base import BaseCommand


HASHED_PREFIX_RE = re.compile(r'^(pbkdf2_sha256|pbkdf2_sha1|argon2|scrypt)\$')


class Command(BaseCommand):
    help = "Re-hash plain-text Supabase passwords in seva_auth_user."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Do not write updates; only print what would change.",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Limit number of users processed (0 = no limit).",
        )

    def handle(self, *args, **options):
        dry_run = bool(options.get("dry_run", False))
        limit = int(options.get("limit") or 0)

        try:
            from supabase_config import get_supabase_client
        except ImportError:
            self.stderr.write(self.style.ERROR("supabase_config not found."))
            return

        supabase = get_supabase_client()
        try:
            q = supabase.table("seva_auth_user").select("id,password").execute()
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"Supabase error: {e}"))
            return

        users = list(q.data or [])
        if limit > 0:
            users = users[:limit]

        rehashed = 0
        skipped = 0
        failed = 0

        for row in users:
            user_id = row.get("id")
            raw_pwd = row.get("password")
            if user_id is None:
                continue
            if raw_pwd is None:
                continue

            raw_str = raw_pwd if isinstance(raw_pwd, str) else str(raw_pwd)
            raw_str = raw_str.strip()

            # If it already looks like a Django hash, skip.
            if raw_str and HASHED_PREFIX_RE.match(raw_str):
                skipped += 1
                continue

            if not raw_str:
                # Nothing to re-hash.
                skipped += 1
                continue

            new_hash = make_password(raw_str)
            if dry_run:
                self.stdout.write(f"[dry-run] user_id={user_id} would be rehashed.")
                rehashed += 1
                continue

            try:
                supabase.table("seva_auth_user").update({"password": new_hash}).eq("id", user_id).execute()
                rehashed += 1
            except Exception:
                failed += 1

        mode = "DRY-RUN" if dry_run else "WRITE"
        self.stdout.write(self.style.SUCCESS(f"{mode} complete. rehashed={rehashed}, skipped={skipped}, failed={failed}"))

