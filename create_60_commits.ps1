# Create 60 commits from current project (final files) - run from d:\hamro-sewa
# Usage: cd d:\hamro-sewa; .\create_60_commits.ps1
# Then: add remote and push (see end of script or PUSH_TO_GITHUB_STEPS.md)

Set-Location $PSScriptRoot

# Remove existing .git so we start fresh (optional - comment out if you already have commits you want to keep)
if (Test-Path .git) {
    Write-Host "Removing existing .git to start fresh for 60 commits..."
    Remove-Item -Recurse -Force .git
}

git init

# Don't stop on git warnings (e.g. LF/CRLF) - they write to stderr and would exit the loop
$ErrorActionPreference = "Continue"

# 60 batches: each (path(s), commit message). Paths relative to repo root.
# Add only paths that exist; Git will respect .gitignore.
$batches = @(
    @{ path = ".gitignore"; msg = "chore: add project gitignore" },
    @{ path = "PUSH_TO_GITHUB_STEPS.md"; msg = "docs: add GitHub push instructions" },
    @{ path = "backend/requirements.txt"; msg = "chore(backend): add Python dependencies" },
    @{ path = "backend/manage.py"; msg = "chore(backend): add Django manage script" },
    @{ path = "backend/core/__init__.py"; msg = "build(backend): add core package" },
    @{ path = "backend/core/settings.py"; msg = "build(backend): add Django settings" },
    @{ path = "backend/core/urls.py"; msg = "build(backend): add root URL config" },
    @{ path = "backend/core/wsgi.py"; msg = "build(backend): add WSGI config" },
    @{ path = "backend/core/asgi.py"; msg = "build(backend): add ASGI config" },
    @{ path = "backend/supabase_config.py"; msg = "build(backend): add Supabase config" },
    @{ path = "backend/authentication/__init__.py"; msg = "build(auth): add auth app package" },
    @{ path = "backend/authentication/models.py"; msg = "feat(auth): add user models" },
    @{ path = "backend/authentication/views.py"; msg = "feat(auth): add auth views" },
    @{ path = "backend/authentication/serializers.py"; msg = "feat(auth): add auth serializers" },
    @{ path = "backend/authentication/urls.py"; msg = "feat(auth): add auth URLs" },
    @{ path = "backend/authentication/backends.py"; msg = "feat(auth): add custom auth backends" },
    @{ path = "backend/authentication/admin.py"; msg = "chore(auth): add admin config" },
    @{ path = "backend/authentication/migrations"; msg = "chore(auth): add migrations" },
    @{ path = "backend/authentication/management"; msg = "feat(auth): add sync Supabase command" },
    @{ path = "backend/services/__init__.py"; msg = "build(services): add services app" },
    @{ path = "backend/services/models.py"; msg = "feat(services): add service models" },
    @{ path = "backend/services/views.py"; msg = "feat(services): add service views" },
    @{ path = "backend/services/serializers.py"; msg = "feat(services): add serializers" },
    @{ path = "backend/services/urls.py"; msg = "feat(services): add service URLs" },
    @{ path = "backend/services/admin.py"; msg = "chore(services): add admin" },
    @{ path = "backend/services/migrations"; msg = "chore(services): add migrations" },
    @{ path = "backend/services/management"; msg = "chore(services): add management commands" },
    @{ path = "backend/static"; msg = "chore(backend): add static files" },
    @{ path = "backend/templates"; msg = "chore(backend): add admin templates" },
    @{ path = "backend/create_tables.py"; msg = "chore(backend): add create_tables script" },
    @{ path = "backend/create_tables.sql"; msg = "chore(backend): add create_tables SQL" },
    @{ path = "backend/create_seva_payment_table.sql"; msg = "chore(backend): add payment table SQL" },
    @{ path = "backend/create_referral_loyalty_tables.sql"; msg = "chore(backend): add referral tables SQL" },
    @{ path = "backend/create_seva_notification_table.sql"; msg = "chore(backend): add notification table SQL" },
    @{ path = "backend/create_seva_provider_verification_table.sql"; msg = "chore(backend): add verification table SQL" },
    @{ path = "backend/create_sqlite_service_tables.sql"; msg = "chore(backend): add service tables SQL" },
    @{ path = "backend/create_promotional_blogs_tables.sql"; msg = "chore(backend): add blogs tables SQL" },
    @{ path = "backend/create_password_reset_table.sql"; msg = "chore(backend): add password reset table SQL" },
    @{ path = "backend/add_courier_service_monish.sql"; msg = "chore(backend): add courier service data" },
    @{ path = "backend/add_electrician_service.sql"; msg = "chore(backend): add electrician service data" },
    @{ path = "backend/add_nayanka_nishma_services.sql"; msg = "chore(backend): add nayanka nishma services" },
    @{ path = "backend/add_subcategories_services.sql"; msg = "chore(backend): add subcategories SQL" },
    @{ path = "backend/add_referral_columns_sqlite.sql"; msg = "chore(backend): add referral columns SQL" },
    @{ path = "backend/populate_data.py"; msg = "chore(backend): add populate_data script" },
    @{ path = "backend/simple_populate.py"; msg = "chore(backend): add simple_populate script" },
    @{ path = "backend/populate_supabase_tables.py"; msg = "chore(backend): add Supabase populate script" },
    @{ path = "backend/mock_services.json"; msg = "chore(backend): add mock services JSON" },
    @{ path = "frontend/pubspec.yaml"; msg = "chore(frontend): add Flutter pubspec" },
    @{ path = "frontend/pubspec.lock"; msg = "chore(frontend): lock dependencies" },
    @{ path = "frontend/analysis_options.yaml"; msg = "chore(frontend): add analysis options" },
    @{ path = "frontend/README.md"; msg = "docs(frontend): add README" },
    @{ path = "frontend/.gitignore"; msg = "chore(frontend): add frontend gitignore" },
    @{ path = "frontend/lib/main.dart"; msg = "feat(app): add main entry point" },
    @{ path = "frontend/lib/core"; msg = "feat(app): add core theme and locale" },
    @{ path = "frontend/lib/services"; msg = "feat(app): add API and token services" },
    @{ path = "frontend/lib/features/splash"; msg = "feat(app): add splash screen" },
    @{ path = "frontend/lib/features/onboarding"; msg = "feat(app): add onboarding flow" },
    @{ path = "frontend/lib/features/auth"; msg = "feat(auth): add login and registration screens" },
    @{ path = "frontend/lib/features/shell"; msg = "feat(app): add shell and tabs" },
    @{ path = "frontend/lib/features/dashboard"; msg = "feat(app): add dashboard and drawer" },
    @{ path = "frontend/lib/features/profile"; msg = "feat(profile): add profile screens" },
    @{ path = "frontend/lib/features/orders"; msg = "feat(orders): add order and booking flow" },
    @{ path = "frontend/lib/features/payment"; msg = "feat(payment): add eSewa payment screen" },
    @{ path = "frontend/lib/features/reviews"; msg = "feat(reviews): add ratings and write review" },
    @{ path = "frontend/lib/features/customer"; msg = "feat(customer): add customer screens and shell" },
    @{ path = "frontend/lib/features/provider"; msg = "feat(provider): add provider screens and shell" },
    @{ path = "frontend/android"; msg = "chore(android): add Android project" },
    @{ path = "frontend/assets"; msg = "chore(frontend): add assets" },
    @{ path = "frontend/web"; msg = "chore(web): add web support" },
    @{ path = "frontend/test"; msg = "chore(frontend): add test folder" },
    @{ path = "frontend/run_on_emulator.ps1"; msg = "chore(frontend): add run script" }
)

$total = $batches.Count
$n = 0
foreach ($b in $batches) {
    $n++
    $path = $b.path
    $msg = $b.msg
    if (-not (Test-Path $path -ErrorAction SilentlyContinue)) {
        Write-Host "[$n/$total] Skip (not found): $path"
        continue
    }
    # Suppress all git output so LF/CRLF warnings don't stop the script
    & git add $path 2>&1 | Out-Null
    $status = & git status --short 2>&1
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "[$n/$total] Skip (nothing to commit): $path"
        continue
    }
    & git commit -m $msg 2>&1 | Out-Null
    Write-Host "[$n/$total] Committed: $msg"
}

# Add any remaining untracked files in one final commit so nothing is left out
& git add -A 2>&1 | Out-Null
$status = & git status --short 2>&1
if (-not [string]::IsNullOrWhiteSpace($status)) {
    & git commit -m "chore: add remaining project files" 2>&1 | Out-Null
    Write-Host "Committed remaining files."
}

$count = (git rev-list --count HEAD 2>$null)
Write-Host "`nDone. Total commits: $count"
Write-Host "`nNext: add remote and push."
Write-Host "  git remote add origin https://github.com/NirjalaGhimire/Nirjala_Ghimire_HamroSeva.git"
Write-Host "  git branch -M main"
Write-Host "  git push -u origin main --force"
