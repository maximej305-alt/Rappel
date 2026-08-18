# Build Script pour Rappel+
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -ErrorAction SilentlyContinue

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RAPPEL+ — BUILD SCRIPT PRODUCTION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Analyse statique
Write-Host "`n[1/4] Analyse du code source..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors de l'analyse. Interruption." -ForegroundColor Red
    exit 1
}

# 2. Execution des tests
Write-Host "`n[2/4] Lancement des tests unitaires et widget..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur dans les tests. Interruption." -ForegroundColor Red
    exit 1
}

# 3. Build APK Debug / Release split-per-abi
Write-Host "`n[3/4] Build des APKs (split per ABI)..." -ForegroundColor Yellow
flutter build apk --split-per-abi --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors du build APK." -ForegroundColor Red
    exit 1
}

# 4. Build AppBundle (AAB pour Google Play Store)
Write-Host "`n[4/4] Build de l'AppBundle (AAB)..." -ForegroundColor Yellow
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors du build AppBundle." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  BUILDS TERMINES AVEC SUCCES ! 🎉" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Artifacts générés :"
Write-Host " - APKs : build\app\outputs\flutter-apk\"
Write-Host " - AAB  : build\app\outputs\bundle\release\"
