# Socius Dictado

Dictado por voz tipo **WhisperFlow** para la Mac — uso interno, no se publica.
Un círculo púrpura flotante (estilo AssistiveTouch del iPhone) siempre encima de
cualquier app o web: hablas sin límite, se transcribe con **tu API de OpenAI** y
el texto se **pega donde esté el cursor**.

Replica el enfoque de la app existente *OpenAI Transcriber* (audio mono 16 kHz,
chunks en paralelo, idioma autodetectado, rápido).

## Requisitos
- macOS 14+ (probado en Sequoia 15.7, Intel).
- Command Line Tools de Xcode (`xcode-select --install`). **No** necesita Xcode completo.
- Una API key de OpenAI (se guarda en el Keychain, nunca en el repo).

## Instalación (una sola vez)
```bash
cd ~/socius-dictado
./install.sh
```
Esto:
1. Compila y ensambla `Socius Dictado.app` (firma ad-hoc local).
2. Guarda tu OpenAI API key en el Keychain (la toma de `OPENAI_API_KEY` o de
   `~/.zprofile`; si no, te la pide). Servicio `com.socius.dictado`.

Luego ábrela:
```bash
open "~/socius-dictado/Socius Dictado.app"
```
(Opcional: cópiala a `/Applications` para tenerla fija, o agrégala a
*Ajustes → General → Ítems de inicio* para que arranque con la Mac.)

## Permisos que pide macOS (la primera vez)
- **Micrófono** — para grabar.
- **Accesibilidad** (Ajustes → Privacidad y seguridad → Accesibilidad) — es lo
  que permite **pegar en el cursor**. Activa *Socius Dictado* en esa lista.
  Si no la das, el texto igual queda en el portapapeles (modo Copiar).

## Cómo se usa
- **Clic** en el micrófono → empieza a grabar (sin límite de duración).
- **Clic** otra vez → transcribe (anillo girando) y **pega** el texto en el
  campo enfocado. El círculo se pone **verde ~1 s** al terminar.
- Si **no hay** campo de texto enfocado, el texto queda en el portapapeles.
- **Pasa el mouse por encima** para ver: **Copiar**, **Reintentar**, **Cancelar**.
- Arrastra el círculo para moverlo a donde quieras.

## Ajustes (sin recompilar)
```bash
# Color púrpura exacto de la marca
defaults write com.socius.dictado SociusPurpleHex "#6D28D9"

# Modelo: rápido (default) o más preciso
defaults write com.socius.dictado SociusModel "gpt-4o-mini-transcribe"   # rápido
defaults write com.socius.dictado SociusModel "gpt-4o-transcribe"        # preciso
```

## Desarrollo
```bash
swift build -c release     # compila el binario
./build.sh                 # compila + arma el .app firmado
```

Código en `Sources/SociusDictado/`:
- `FloatingPanel` / `AppDelegate` — ventana flotante en todos los Spaces.
- `OrbView` — el círculo, estados y menú al hover.
- `DictationController` — máquina de estados (idle → grabando → transcribiendo → listo).
- `AudioRecorder` — graba a m4a mono 16 kHz.
- `Transcriber` — OpenAI API, parte audios largos en chunks paralelos.
- `Paster` — portapapeles + Cmd+V (Accessibility) y detección de campo enfocado.
- `Keychain` — guarda/lee la API key.
