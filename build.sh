#!/usr/bin/env bash
# Builds the SPM executable and assembles a runnable, ad-hoc signed .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP="Socius Dictado.app"
BIN="SociusDictado"

echo "==> swift build (release)"
swift build -c release

BUILT="$(swift build -c release --show-bin-path)/$BIN"
[ -f "$BUILT" ] || { echo "No se encontró el binario en $BUILT"; exit 1; }

echo "==> Ensamblando $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILT" "$APP/Contents/MacOS/$BIN"
cp Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" || true

echo "==> Firmando ad-hoc (identidad local estable para los permisos de macOS)"
codesign --force --deep --sign - "$APP"

echo "✅ Listo: $(pwd)/$APP"
echo "   Ábrela con:  open \"$(pwd)/$APP\""
