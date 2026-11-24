# Socius Dictado (macOS)

Dictado por voz con tu propia API de OpenAI, estilo WhisperFlow. Un **círculo
flotante** púrpura, siempre encima de todo: haces clic, hablas, y el texto se
**pega solo donde está tu cursor**.

> Freebie del curso de Socius. 🎤

## 🚀 La forma más fácil: deja que Claude te guíe
Esta app trae un asistente de instalación. Si usas **Claude Code**:
1. Descarga/clona esta carpeta.
2. Abre **Claude Code** dentro de la carpeta.
3. Dile: **"ayúdame a instalar Socius Dictado"**.

Claude lee las instrucciones del repo (`CLAUDE.md`) y te lleva **paso a paso**: crear tu
API key de OpenAI, instalar, dar los permisos y probar. Hace él la parte técnica; tú solo
creas tu key y das los clics de permiso.

## Instalación manual (si prefieres hacerlo tú)
**Requisitos:** macOS 14+, Command Line Tools de Xcode (`xcode-select --install`), y una
API key de OpenAI (de [platform.openai.com](https://platform.openai.com/api-keys) — es de
pago por uso, cuesta centavos).

```bash
cd socius-dictado
./install.sh          # compila, firma, instala en /Applications y pide tu API key
open "/Applications/Socius Dictado.app"
```

**Permisos (una vez):** la primera vez que dictes, macOS pide **Accesibilidad** (para pegar).
Actívala en *Ajustes del Sistema → Privacidad y seguridad → Accesibilidad* y **cierra y
reabre la app** (el permiso solo aplica al reabrir). El **Micrófono** se concede al grabar.

## Cómo se usa
- **Clic** en el círculo (o **⌘⇧Espacio**) → graba → clic de nuevo → transcribe y **pega** en el cursor.
- **⌘⇧D** — mostrar / ocultar el círculo.
- **Pasa el mouse** → botón **Abrir** (ventana con Historial y Ajustes).
- Arrastra el círculo para moverlo (no se sale de la pantalla).

## Funciones
Transcripción OpenAI (rápido/preciso), idioma auto/es/en, **modos IA** antes de pegar
(limpiar, bullets, correo, traducir), **diccionario personal**, historial con **títulos por
IA**, buscar/exportar/borrar varias, contador de uso, arranque al iniciar sesión.

## Privacidad
Tu API key vive solo en el **Keychain** (nunca en el repo). El audio se envía a OpenAI para
transcribir; solo el texto se guarda localmente en el historial.

## Detalle técnico / desarrollo
Todo (features, arquitectura, gotchas, troubleshooting) está en **[PLAYBOOK.md](PLAYBOOK.md)**.
Reconstruir tras un cambio: `./build.sh` (mantiene la firma estable, el permiso no se cae).
