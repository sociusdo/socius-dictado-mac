# Socius Dictado — Playbook completo

App nativa de macOS para **dictado por voz con la API de OpenAI**, estilo WhisperFlow.
Un círculo flotante púrpura, siempre encima de todo, que graba tu voz, la transcribe
y **pega el texto solo donde esté tu cursor**. Uso interno/personal.

Este documento tiene **todo** lo necesario para instalarla y entenderla en cualquier
MacBook, con cada arreglo y gotcha que costó resolver. Si sigues la sección
**"Instalación"** al pie de la letra (sobre todo el paso de permisos), funciona a la primera.

---

## 1. Qué hace (todas las features)

- **Círculo flotante** púrpura (gradiente a negro), 48px, siempre encima de cualquier
  app, en todos los Spaces y sobre apps en pantalla completa. Sin ícono en el Dock.
- **Grabar sin límite**: clic en el círculo para empezar (se pone rojo), clic para parar.
  También con atajo global **⌘⇧Espacio**.
- **Transcribe con OpenAI** (modelos `gpt-4o-mini-transcribe` rápido / `gpt-4o-transcribe`
  preciso), idioma auto-detectado, troceado en paralelo para audios largos.
- **Pega solo donde está el cursor** (y además deja el texto en el portapapeles como
  respaldo, por si el pegado automático no cae en algún app → ⌘V manual).
- **Anillo girando** mientras transcribe; **verde** cuando pega; **ámbar** = solo copió
  (le falta permiso de Accesibilidad).
- **Menú al pasar el mouse**: en reposo muestra **"Abrir"**; mientras graba muestra
  **"Cancelar"** (descarta sin transcribir).
- **Atajo global ⌘⇧D**: mostrar / ocultar el círculo.
- **Arrastre acotado**: el círculo nunca se sale de la pantalla; toca el borde exacto.
- **Ventana (Abrir)** con dos pestañas:
  - **Historial**: cada transcripción con **título generado por IA** (resumen corto),
    fecha (mm/dd/yy), duración y # de palabras. Buscar, **casillas para borrar varias**,
    exportar a `.md`, ver/copiar el texto completo.
  - **Ajustes**: modelo (rápido/preciso), idioma (auto/es/en), **modo IA** antes de pegar
    (limpiar/puntuar, bullets, redactar como correo, traducir a inglés), **diccionario
    personal** (mejora el reconocimiento de nombres/marcas como Kommo, Socius…),
    **API key** de OpenAI (se guarda en el Keychain), color del círculo, sonido al
    empezar/terminar, **arrancar al iniciar sesión**, contador de uso/costo, estado de
    permisos y botón **Salir**.
- **Salir**: menú de la app (⌘Q) o botón en Ajustes.

---

## 2. Requisitos en la Mac destino

- macOS 14 o superior (probado en macOS 15 Sequoia, Intel y Apple Silicon).
- **Command Line Tools** de Xcode (NO hace falta Xcode completo):
  ```bash
  xcode-select --install
  ```
- **Swift** (viene con los Command Line Tools). Verifica: `swift --version`.
- Una **API key de OpenAI** (empieza con `sk-...`). Es secreta; se guarda en el Keychain,
  nunca en el repo.
- La carpeta del proyecto (`socius-dictado`) con todo el código fuente.

---

## 3. Instalación (paso a paso)

1. **Copia la carpeta** `socius-dictado` a la Mac destino (home del usuario, ej. `~/socius-dictado`).
   No la pongas dentro de Google Drive/iCloud (sincronizar rompe el build).

2. **Compila e instala** (crea la firma estable, arma el `.app` y lo copia a `/Applications`):
   ```bash
   cd ~/socius-dictado && ./install.sh
   ```
   El instalador te pedirá la API key de OpenAI si no la encuentra; se guarda en el Keychain.

3. **Abre la app** (ya quedó en Applications):
   ```bash
   open "/Applications/Socius Dictado.app"
   ```
   Verás el círculo púrpura abajo a la derecha.

4. **Concede permisos (CLAVE — léelo completo).** La primera vez que dictes, macOS pide
   **Accesibilidad** (para poder pegar). Haz exactamente esto:
   - Te sale el prompt *"Socius Dictado would like to control this computer…"* → **Open System Settings**.
   - En **Ajustes del Sistema → Privacidad y seguridad → Accesibilidad**, **activa** "Socius Dictado".
   - **MUY IMPORTANTE: cierra y vuelve a abrir la app** (⌘Q y `open` de nuevo). El permiso
     de Accesibilidad **solo aplica al reabrir**.
   - El **Micrófono** se concede una sola vez la primera vez que grabas.

5. Listo. Dicta con el círculo o con **⌘⇧Espacio**.

> Si ya habías instalado una versión vieja y el pegado no funciona aunque el switch esté
> activado, mira **Troubleshooting → "El pegado no funciona"**.

---

## 4. Gotchas resueltos (POR QUÉ está hecho así)

Estos son los muros que costó derribar. Si alguien reconstruye o modifica la app, que no
los vuelva a pisar:

### 4.1 Firma de código ESTABLE (si no, el permiso se cae en cada build)
macOS amarra los permisos (Accesibilidad, Micrófono) a la **firma** de la app. Una firma
ad-hoc (`codesign -s -`) cambia en cada compilación → macOS invalida el permiso y lo
vuelve a pedir cada vez. **Solución**: `build.sh` crea UNA identidad self-signed estable
llamada **"Socius Dictado Dev"** en el login keychain y firma siempre con ella, así el
*designated requirement* no cambia entre builds y el permiso se mantiene.
- El PKCS12 necesita `openssl pkcs12 -export -legacy` (OpenSSL 3 usa un MAC que el keychain
  de Apple no verifica).
- El cert sale `CSSMERR_TP_NOT_TRUSTED` (no confiable) pero **codesign firma igual** y el
  permiso funciona (TCC empareja por el leaf del cert, no por confianza).
- Chequear si existe la identidad con `security find-identity -p codesigning` **sin `-v`**
  (`-v` oculta los cert no confiables).

### 4.2 Entradas viejas de TCC + hay que RELANZAR
Si una versión anterior se firmó ad-hoc y concediste Accesibilidad, queda una entrada
"fantasma" en la lista que **no empareja** con la firma nueva. El switch se ve encendido
pero `AXIsProcessTrusted()` devuelve `false` para siempre. **Solución**:
```bash
tccutil reset Accessibility com.socius.dictado
```
…y volver a conceder + **relanzar la app** (el permiso solo se lee al arrancar el proceso).

### 4.3 Clics en una ventana flotante: AppKit, NO SwiftUI
En una `NSPanel` borderless y *non-activating* (para no robarle el foco a tu textbox),
**los gestos de SwiftUI (`.onTapGesture`, botones) NO reciben el clic** — se los traga el
sistema. Por eso "Cancelar" nunca funcionaba. **Solución**: `HitRegionView` (AppKit) maneja
TODOS los clics en `mouseDown` y despacha según la posición (círculo vs menú). SwiftUI solo
dibuja. El hover se detecta con un `NSTrackingArea`.

### 4.4 Pegar = Accesibilidad obligatoria
Pegar en otra app en macOS moderno **requiere** permiso de Accesibilidad (se sintetiza
⌘V con `CGEvent`). No hay forma de evitarlo. Por eso el flujo de permisos es tan importante.
El texto SIEMPRE se copia al portapapeles como respaldo, así que ⌘V manual siempre funciona.

### 4.5 Arrastre acotado vía `windowDidMove`
Sobrescribir `setFrame`/`setFrameOrigin` NO intercepta el arrastre nativo del sistema
(`isMovableByWindowBackground`). Se usa `windowDidMove` para re-acotar el origen contra
`screen.frame` por el radio del círculo, así nunca se sale de pantalla.

### 4.6 `NSSavePanel` en app accessory
El panel de guardar se abría detrás (modal invisible, sonido "funk"). Se usa
`beginSheetModal(for:)` + `NSApp.activate` para que salga al frente.

---

## 5. Arquitectura (archivo por archivo)

Todo en `Sources/SociusDictado/`:

| Archivo | Rol |
|---|---|
| `main.swift` | Entry point; crea el `NSApplication`, política `.accessory`. |
| `AppDelegate.swift` | Arma el panel flotante, el `HitRegionView`, cablea clics/hover a AppKit, registra atajos globales, construye el menú, loguea el estado de Accesibilidad al arrancar. Incluye `FirstMouseHostingView` (acepta el primer clic). |
| `FloatingPanel.swift` | `FloatingPanel` (NSPanel flotante, non-activating, todos los Spaces + fullscreen, clamp de arrastre) y `HitRegionView` (maneja mouseDown del círculo/menú + hover). |
| `OrbView.swift` | SwiftUI: dibuja el círculo (gradiente, anillo, ícono por estado) y el menú. Solo dibuja; no maneja clics. |
| `DictationController.swift` | Máquina de estados (idle/recording/transcribing/done/copiedOnly/error/needsKey), graba→transcribe→(modo IA)→entrega, guarda en historial, dispara título IA, sonidos, alerta de Accesibilidad. |
| `AudioRecorder.swift` | Graba a `.m4a` mono 16kHz AAC, medición de nivel para la animación. |
| `Transcriber.swift` | Llama a `/v1/audio/transcriptions`; trocea audios largos en paralelo; manda diccionario (`prompt`) e idioma. |
| `TextTransformer.swift` | Modos IA (limpiar/bullets/correo/traducir) y títulos IA vía `/v1/chat/completions` (gpt-4o-mini). Nunca bloquea el pegado si falla. |
| `TranscriptStore.swift` | Persiste el historial en `~/Library/Application Support/SociusDictado/history.json`; título IA con fallback a primera línea. |
| `Paster.swift` | Copia al portapapeles y sintetiza ⌘V (`CGEvent`), requiere Accesibilidad. |
| `Keychain.swift` | Guarda/lee la API key (servicio `com.socius.dictado`). |
| `Permissions.swift` | Estados y prompts de Micrófono y Accesibilidad. |
| `HotKeyManager.swift` | Atajos globales (Carbon `RegisterEventHotKey`): ⌘⇧D y ⌘⇧Espacio. |
| `MainWindow.swift` | Ventana Historial + Ajustes (SwiftUI). |
| `Theme.swift` | Colores de marca y gradiente. |
| `Diag.swift` | Log de diagnóstico a `debug.log`. |
| `build.sh` | Compila (SPM), arma el `.app`, firma con la identidad estable, instala en `/Applications`. |
| `install.sh` | Corre build.sh + siembra la API key en el Keychain. |

---

## 6. Personalización rápida

- **Color del círculo**: Ajustes → Apariencia (hex), o `defaults write com.socius.dictado SociusPurpleHex "#6D28D9"`.
- **Modelo por defecto**: Ajustes → Transcripción, o `defaults write com.socius.dictado SociusModel "gpt-4o-transcribe"`.
- **Diccionario, idioma, modo IA, sonido, login item**: todo en Ajustes.
- **Reconstruir tras un cambio de código**: `cd ~/socius-dictado && ./build.sh` (mantiene el permiso, misma firma).

---

## 7. Troubleshooting

**El pegado no funciona (el texto no cae en el textbox):**
1. Ajustes → Permisos: ¿Accesibilidad en verde? Si no:
   ```bash
   tccutil reset Accessibility com.socius.dictado
   ```
2. Reabre la app, concede Accesibilidad, y **cierra y vuelve a abrir** (clave).
3. El texto siempre queda copiado → ⌘V manual como respaldo.

**El círculo desapareció de la pantalla:** reábrela (`open "/Applications/Socius Dictado.app"`);
vuelve a su esquina. También **⌘⇧D** lo muestra/oculta.

**Me pide permiso del micrófono cada vez:** era síntoma de firma inestable; con la firma
estable no debe pasar. Si pasa, reinstala con `./install.sh` y concede una vez.

**Ver qué está pasando:** `cat ~/Library/Application\ Support/SociusDictado/debug.log`
(registra el estado de Accesibilidad al arrancar y cada intento de pegado).

**La firma falló y cayó a ad-hoc:** asegúrate de que `openssl` soporte `-legacy` y que el
login keychain esté desbloqueado; reintenta `./build.sh`.

---

## 8. Privacidad / seguridad

- La API key vive **solo en el Keychain** del usuario (servicio `com.socius.dictado`),
  nunca en el repo ni en el código.
- El audio se envía a la API de OpenAI para transcribir; no se guarda audio en disco
  (solo el texto del historial, localmente).
- La app es de firma local (self-signed); es para uso personal/interno, no distribución
  pública por la App Store.
