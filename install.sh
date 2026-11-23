#!/usr/bin/env bash
# One-time setup: compila la app y guarda tu OpenAI API key en el Keychain.
set -euo pipefail
cd "$(dirname "$0")"

APP="Socius Dictado.app"
SERVICE="com.socius.dictado"
ACCOUNT="openai_api_key"

# 1) Compilar / ensamblar la app primero (para poder darle acceso al Keychain).
./build.sh
APP_PATH="$(pwd)/$APP"

# 2) Guardar la API key en el Keychain si aún no está.
if security find-generic-password -s "$SERVICE" -a "$ACCOUNT" >/dev/null 2>&1; then
  echo "🔑 La API key ya estaba guardada en el Keychain."
else
  KEY="${OPENAI_API_KEY:-}"
  if [ -z "$KEY" ] && [ -f "$HOME/.zprofile" ]; then
    KEY="$(grep -Eo 'OPENAI_API_KEY=\"?[^\"]+' "$HOME/.zprofile" | head -1 | sed -E 's/.*=//; s/\"//g')"
  fi
  if [ -z "$KEY" ]; then
    read -r -s -p "Pega tu OpenAI API key (sk-...): " KEY; echo
  fi
  [ -n "$KEY" ] || { echo "No se dio ninguna key. Abortando."; exit 1; }
  # -T autoriza a la app a leerla sin preguntar; si macOS igual pregunta,
  # haz clic en "Permitir siempre" una vez.
  security add-generic-password -U -s "$SERVICE" -a "$ACCOUNT" -w "$KEY" -T "$APP_PATH" -T /usr/bin/security
  echo "🔑 API key guardada en el Keychain."
fi

echo
echo "✅ Todo listo."
echo "   Para abrir la app:  open \"$APP_PATH\""
echo "   (O cópiala a /Applications si la quieres permanente.)"
echo
echo "La primera vez macOS te pedirá permisos de Micrófono y Accesibilidad."
echo "Acepta ambos (Accesibilidad es lo que permite pegar en el cursor)."
