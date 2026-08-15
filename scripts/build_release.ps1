# ============================================================
# TripJio — Release APK Builder
# ============================================================
# Usage:  powershell -ExecutionPolicy Bypass -File build_release.ps1
#
# Produces a signed (or debug-signed) APK ready for installation
# on test phones or upload to Play Store internal testing.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  TripJio — Release Build" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Clean previous build ───────────────────────────────
Write-Host "▶ Cleaning previous build..." -ForegroundColor Yellow
flutter clean | Out-Null

# ─── 2. Get dependencies ───────────────────────────────────
Write-Host "▶ Getting dependencies..." -ForegroundColor Yellow
flutter pub get | Out-Null

# ─── 3. Run unit tests (if any) ────────────────────────────
if (Test-Path "test/unit") {
    Write-Host "▶ Running unit tests..." -ForegroundColor Yellow
    flutter test test/unit/ 2>&1 | Tee-Object -Variable testOutput | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Unit tests failed — fix before releasing" -ForegroundColor Red
        Write-Host $testOutput
        exit 1
    }
    Write-Host "✅ All unit tests passed" -ForegroundColor Green
} else {
    Write-Host "▶ Skipping tests — test/unit/ not found" -ForegroundColor DarkGray
}

# ─── 4. Static analysis ────────────────────────────────────
Write-Host "▶ Running flutter analyze..." -ForegroundColor Yellow
$analyzeOut = flutter analyze --no-fatal-infos 2>&1 | Out-String
if ($analyzeOut -match "error -") {
    Write-Host "❌ flutter analyze found errors" -ForegroundColor Red
    Write-Host $analyzeOut
    exit 1
}
Write-Host "✅ Static analysis clean" -ForegroundColor Green

# ─── 5. Build release APK ──────────────────────────────────
Write-Host ""
Write-Host "▶ Building release APK..." -ForegroundColor Yellow
Write-Host "  (this takes 3–5 minutes — minification + obfuscation)" -ForegroundColor Gray

flutter build apk --release --no-tree-shake-icons

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ APK build failed" -ForegroundColor Red
    exit 1
}

# ─── 6. Show output ────────────────────────────────────────
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    $sizeMB = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  ✅ APK Built Successfully" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  📦 Location: $apkPath" -ForegroundColor White
    Write-Host "  📏 Size:     $sizeMB MB" -ForegroundColor White
    Write-Host ""
    Write-Host "  Next steps:"
    Write-Host "    1. Copy this APK to your phones (WhatsApp / USB / Google Drive)"
    Write-Host "    2. Enable 'Install from Unknown Sources' on each phone"
    Write-Host "    3. Tap the APK to install"
    Write-Host "    4. For Play Store upload, build an AAB instead:"
    Write-Host "       flutter build appbundle --release"
    Write-Host ""
} else {
    Write-Host "❌ APK not found at expected location" -ForegroundColor Red
    exit 1
}
