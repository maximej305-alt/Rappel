#!/usr/bin/env bash
set -e

echo "========================================"
echo "  RAPPEL+ — BUILD SCRIPT (LINUX/MAC)"
echo "========================================"

echo ""
echo "[1/4] Flutter Analyze..."
flutter analyze

echo ""
echo "[2/4] Flutter Test..."
flutter test

echo ""
echo "[3/4] Build APK split-per-abi..."
flutter build apk --split-per-abi --release

echo ""
echo "[4/4] Build AppBundle..."
flutter build appbundle --release

echo ""
echo "========================================"
echo "  BUILD COMPLET RÉUSSI !"
echo "========================================"
