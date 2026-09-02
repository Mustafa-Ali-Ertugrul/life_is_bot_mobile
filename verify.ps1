# verify.ps1 - quality gate. Run after every session. Clean = ship.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$fail = 0

function Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:fail++ }
function Pass($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }

Write-Host ""
Write-Host "=== 1. flutter analyze ===" -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { Fail "flutter analyze" } else { Pass "flutter analyze" }

Write-Host ""
Write-Host "=== 2. flutter test ===" -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { Fail "flutter test" } else { Pass "flutter test" }

Write-Host ""
Write-Host "=== 3. Manifest checks ===" -ForegroundColor Cyan
$manifest = Get-Content "android\app\src\main\AndroidManifest.xml" -Raw
if ($manifest -match 'USE_EXACT_ALARM') { Fail "Manifest: USE_EXACT_ALARM must be absent (Play policy)" } else { Pass "exact-alarm permission set" }
if ($manifest -match 'WRITE_STEPS') { Fail "Manifest: WRITE_STEPS must be absent" } else { Pass "health permission set" }
$svc = [regex]::Match($manifest, '(?s)<service\b[^>]*BackgroundService[^>]*>')
if ($svc.Success -and $svc.Value -match 'android:exported="true"') { Fail "Manifest: BackgroundService exported must be false" } else { Pass "service exported=false" }

Write-Host ""
Write-Host "=== 4. Release signing ===" -ForegroundColor Cyan
if (-not (Test-Path "android\key.properties")) { Fail "android/key.properties missing - release would be unsigned" } else { Pass "key.properties present" }
if (-not (Test-Path "android\app\keystore\lifeisbot-release.jks")) { Fail "keystore jks missing" } else { Pass "keystore present" }
$gradle = Get-Content "android\app\build.gradle.kts" -Raw
if ($gradle -notmatch 'create\("release"\)') { Fail "build.gradle.kts: release signingConfig not defined" } else { Pass "release signingConfig defined" }

Write-Host ""
Write-Host "=== 5. Dead dependency check ===" -ForegroundColor Cyan
$libText = (Get-ChildItem -Recurse -Filter *.dart lib | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
$inDeps = $false
foreach ($line in (Get-Content "pubspec.yaml")) {
  if ($line -match '^dependencies:') { $inDeps = $true; continue }
  if ($line -match '^dev_dependencies:') { break }
  if ($inDeps -and $line -match '^\s{2}([a-z_0-9]+):\s') {
    $pkg = $Matches[1]
    if ($pkg -eq 'flutter') { continue }
    if ($libText -notmatch "package:$pkg/") { Fail "pubspec: '$pkg' imported nowhere in lib/" } else { Pass "dep: $pkg" }
  }
}

Write-Host ""
Write-Host "=== 6. flutter build apk --release ===" -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Fail "release build" } else { Pass "release build" }

Write-Host ""
if ($fail -gt 0) { Write-Host "GATE: $fail FAILURES" -ForegroundColor Red; exit 1 }
Write-Host "GATE: CLEAN" -ForegroundColor Green
