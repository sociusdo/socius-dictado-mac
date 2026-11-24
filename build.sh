#!/usr/bin/env bash
# Builds the SPM executable and assembles a runnable .app bundle, signed with a
# STABLE local self-signed identity. The stable identity matters: macOS ties the
# Accessibility (and Microphone) permission to the app's code signature. An
# ad-hoc signature changes on every build, so the grant would drop each rebuild
# and paste would silently stop working. A fixed self-signed cert keeps the same
# designated requirement, so you grant Accessibility ONCE.
set -euo pipefail
cd "$(dirname "$0")"

APP="Socius Dictado.app"
BIN="SociusDictado"
IDENTITY="Socius Dictado Dev"

ensure_identity() {
  # NOTE: no -v — a self-signed cert is "not trusted" so -v (valid only) hides it,
  # but codesign still signs with it fine, and the signature stays stable.
  if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    return 0
  fi
  echo "==> Creando identidad de firma local estable ($IDENTITY) — una sola vez"
  local tmp; tmp="$(mktemp -d)"
  cat > "$tmp/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = $IDENTITY
[ v3 ]
basicConstraints   = critical, CA:false
keyUsage           = critical, digitalSignature
extendedKeyUsage   = critical, codeSigning
EOF
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -config "$tmp/cert.cnf" >/dev/null 2>&1
  # -legacy: OpenSSL 3 defaults to a MAC Apple's keychain can't verify.
  openssl pkcs12 -export -legacy -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
    -out "$tmp/id.p12" -passout pass:socius -name "$IDENTITY" >/dev/null 2>&1
  local kc; kc="$(security default-keychain | tr -d ' "')"
  security import "$tmp/id.p12" -k "$kc" -P socius -A -T /usr/bin/codesign >/dev/null 2>&1
  rm -rf "$tmp"
}

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

if ensure_identity && codesign --force --deep --sign "$IDENTITY" "$APP" 2>/dev/null; then
  echo "==> Firmado con identidad estable: $IDENTITY"
else
  echo "==> (fallback) Firmando ad-hoc — la Accesibilidad podría pedirse de nuevo tras recompilar"
  codesign --force --deep --sign - "$APP"
fi

echo "✅ Listo: $(pwd)/$APP"
echo "   Ábrela con:  open \"$(pwd)/$APP\""
