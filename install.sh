#!/usr/bin/env bash
# One-time setup: compila la app y la instala.
#
# La API key NO se guarda aquí a propósito: se escribe UNA vez dentro de la app
# (Ajustes → API key). Cuando la propia app escribe la llave en el Keychain, ella
# queda como dueña del ítem y la lee en silencio para siempre, sin el molesto
# "permiso del Keychain" (ni después de reiniciar). Sembrarla con la CLI `security`
# haría que la app no sea la dueña y macOS pediría permiso en cada arranque.
set -euo pipefail
cd "$(dirname "$0")"

APP="Socius Dictado.app"

# Compilar / ensamblar / instalar en /Applications (firma estable).
./build.sh

echo
echo "✅ Instalada en /Applications/$APP"
echo
echo "Falta UN paso (una sola vez):"
echo "  1) Abre la app:  open \"/Applications/$APP\""
echo "  2) Pasa el mouse sobre el círculo → Abrir → pestaña Ajustes."
echo "  3) Pega tu API key de OpenAI (sk-...) y dale \"Guardar key\"."
echo
echo "La primera vez macOS pedirá Micrófono y Accesibilidad (para pegar)."
echo "Actívalos y reabre la app. No vuelve a pedir nada después."
