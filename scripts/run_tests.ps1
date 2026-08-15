# ============================================================
# TripJio — Test Runner
# Run all automated tests in one go
# ============================================================
# Usage: powershell -File run_tests.ps1
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  TripJio Test Suite" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$failedTests = 0

# ─── 1. Dart unit tests ─────────────────────────────────────
Write-Host "▶ Running Dart unit tests..." -ForegroundColor Yellow
$result = flutter test test/unit/ 2>&1
$dartExit = $LASTEXITCODE

if ($dartExit -eq 0) {
    Write-Host "✅ Dart unit tests PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ Dart unit tests FAILED" -ForegroundColor Red
    Write-Host $result
    $failedTests++
}

Write-Host ""

# ─── 2. Flutter analyze (static checks) ─────────────────────
Write-Host "▶ Running flutter analyze..." -ForegroundColor Yellow
$analyzeResult = flutter analyze --no-fatal-infos 2>&1 | Out-String

if ($analyzeResult -match "error -") {
    Write-Host "❌ flutter analyze found errors" -ForegroundColor Red
    Write-Host $analyzeResult
    $failedTests++
} else {
    Write-Host "✅ flutter analyze CLEAN" -ForegroundColor Green
}

Write-Host ""

# ─── 3. Build check (compiles without errors) ───────────────
Write-Host "▶ Verifying build compiles..." -ForegroundColor Yellow
$buildResult = flutter build web --no-tree-shake-icons 2>&1 | Out-String

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Web build PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ Web build FAILED" -ForegroundColor Red
    Write-Host $buildResult
    $failedTests++
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
if ($failedTests -eq 0) {
    Write-Host "  ALL AUTOMATED TESTS PASSED ✅" -ForegroundColor Green
} else {
    Write-Host "  $failedTests TEST SUITE(S) FAILED ❌" -ForegroundColor Red
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Open Supabase SQL Editor"
Write-Host "  2. Paste & run: supabase_test_suite.sql"
Write-Host "  3. Check NOTICE output — every test should say ✅ PASS"
Write-Host "  4. Then run manual checks from MANUAL_TEST_PLAN.md"
Write-Host ""

exit $failedTests
