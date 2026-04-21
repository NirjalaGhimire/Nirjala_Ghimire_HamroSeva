"""
Check SMTP config for password-reset email.

  python manage.py password_reset_check
  python manage.py password_reset_check --send you@gmail.com
"""
import os

from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Verify EMAIL_* env for password reset (SMTP only)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--send",
            type=str,
            metavar="EMAIL",
            help="Send a test email to this address",
        )

    def handle(self, *args, **options):
        smtp = bool(os.environ.get("EMAIL_HOST", "").strip())
        user = bool(os.environ.get("EMAIL_HOST_USER", "").strip())
        pw = bool(os.environ.get("EMAIL_HOST_PASSWORD", "").strip())

        self.stdout.write("Password reset email (SMTP):\n")
        self.stdout.write(f"  EMAIL_HOST:          {'set' if smtp else 'MISSING'}")
        self.stdout.write(f"  EMAIL_HOST_USER:     {'set' if user else 'MISSING'}")
        self.stdout.write(f"  EMAIL_HOST_PASSWORD: {'set' if pw else 'MISSING'}")

        if not smtp or not user or not pw:
            self.stdout.write(
                self.style.WARNING(
                    "\nSet EMAIL_HOST, EMAIL_HOST_USER, EMAIL_HOST_PASSWORD, DEFAULT_FROM_EMAIL in backend/.env\n"
                    "See docs/GMAIL_SMTP_PASSWORD_RESET.md\n"
                )
            )

        send_to = options.get("send")
        if send_to:
            from django.conf import settings

            from authentication.password_reset_delivery import send_password_reset_email

            ok, err = send_password_reset_email(send_to, "0000")
            if ok:
                self.stdout.write(self.style.SUCCESS(f"Test send OK to {send_to}"))
            else:
                self.stdout.write(self.style.ERROR(f"Test send failed: {err}"))
                self.stdout.write(f"DEFAULT_FROM_EMAIL={getattr(settings, 'DEFAULT_FROM_EMAIL', '')!r}")
