# Activate emulator and run Hamro Sewa on it
# Run from: d:\hamro-sewa\frontend (or run with full path to this script)

$ErrorActionPreference = "Stop"
$sdk = "D:\Androidstudio\Sdk"
$emulator = "$sdk\emulator\emulator.exe"
$adb = "$sdk\platform-tools\adb.exe"

Write-Host "=== 1. Killing existing emulator/ADB (clean start) ===" -ForegroundColor Cyan
& $adb kill-server 2>$null
Start-Sleep -Seconds 2

Write-Host "`n=== 2. Starting Pixel 6 emulator (new window) ===" -ForegroundColor Cyan
Start-Process -FilePath $emulator -ArgumentList "-avd","Pixel_6" -WindowStyle Normal
Write-Host "Emulator launching... Wait for the Android home screen to appear."

Write-Host "`n=== 3. Waiting 70 seconds for emulator to boot ===" -ForegroundColor Cyan
Start-Sleep -Seconds 70

& $adb start-server | Out-Null
Start-Sleep -Seconds 3

Write-Host "`n=== 4. Checking devices ===" -ForegroundColor Cyan
& $adb devices
$devices = & $adb devices 2>&1 | Out-String
if ($devices -notmatch "emulator-5554\s+device") {
    Write-Host "Emulator still not 'device' (might show offline). Trying anyway..." -ForegroundColor Yellow
}

Write-Host "`n=== 5. Running Flutter app on emulator ===" -ForegroundColor Cyan
flutter run -d emulator-5554
