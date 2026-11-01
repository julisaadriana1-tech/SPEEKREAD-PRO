# SpeakRead Pro: código inicial

App móvil (Android e iOS) para aprender inglés leyendo en voz alta, con corrección de pronunciación palabra por palabra y test de comprensión al final de cada lección.

**Stack:** Flutter · Supabase (Auth, Postgres, Storage, Edge Functions) · Azure Speech (Pronunciation Assessment + Neural TTS) · OpenAI.

---

## Qué incluye

| Carpeta | Contenido |
| --- | --- |
| `app/` | La app Flutter: login, onboarding, inicio, camino por niveles, lectura con audio y vocabulario, **Leer y Repetir** con evaluación real, lectura completa, quiz, resultado, progreso y perfil |
| `supabase/migrations/0001_init.sql` | Las 14 tablas, seguridad (RLS) y la lógica del servidor: `complete_lesson()` (XP, racha, quiz, palabras, desafío, insignias) y `get_dashboard()` |
| `supabase/seed.sql` | 3 lecciones completas (stand-up A2, comunicar un retraso B1, compras de la semana A2), insignias y desafíos |
| `supabase/functions/assess-pronunciation` | Recibe tu grabación, la evalúa con Azure y devuelve el puntaje por palabra y por fonema |
| `supabase/functions/generate-lesson` | Genera lecciones nuevas con OpenAI (solo administradores; quedan como borrador) |
| `scripts/generate-audio.mjs` | Genera el audio nativo de las lecciones con Azure TTS y lo sube a Storage |

> **Seguridad:** las claves de Azure y OpenAI **nunca** van dentro de la app. Viven como "secretos" en Supabase. La app solo conoce la URL de Supabase y la clave pública (anon), que está pensada para eso.

---

## Guía paso a paso

Tiempo estimado la primera vez: 1 a 2 horas. Si te trabás en algún paso, copiá el mensaje de error y pegáselo a Claude.

### Paso 1. Instalar las herramientas

1. **Flutter**: seguí la guía oficial para tu sistema en https://docs.flutter.dev/get-started/install. Al terminar, en una terminal ejecutá `flutter doctor`: todo lo que vas a usar debe tener ✓.
2. **Android Studio** (para el emulador de Android y para generar el APK). Para iPhone necesitás una Mac con **Xcode**.
3. **Visual Studio Code** con la extensión "Flutter" (opcional, pero facilita mucho).
4. **Node.js 18 o superior** (solo para el script de audio): https://nodejs.org
5. **Supabase CLI** (para subir las Edge Functions): https://supabase.com/docs/guides/cli

### Paso 2. Crear el proyecto en Supabase

1. Entrá a https://supabase.com, creá una cuenta y un **New project** (plan gratuito). Guardá la contraseña de la base.
2. Andá a **SQL Editor → New query**, pegá todo el contenido de `supabase/migrations/0001_init.sql` y tocá **Run**.
3. Repetí con `supabase/seed.sql` para cargar las 3 lecciones de ejemplo.
4. En **Authentication → Providers → Email**, para probar más rápido podés desactivar "Confirm email". Volvé a activarlo antes de publicar.
5. En **Project Settings → API** copiá:
   - **Project URL**
   - **anon public key**

### Paso 3. Crear el recurso de Azure Speech

1. Entrá a https://portal.azure.com y creá un recurso **Speech** (buscá "Speech services"). El plan **F0** (gratis) alcanza para probar.
2. Elegí una región, por ejemplo **East US**.
3. En el recurso, abrí **Keys and Endpoint** y copiá **KEY 1** y la **Location/Region** (ej. `eastus`).

### Paso 4. Subir las Edge Functions a Supabase

En una terminal, dentro de la carpeta `speakread/`:

```bash
supabase login
supabase link --project-ref TU_PROJECT_REF      # el código que aparece en la URL de tu proyecto
supabase secrets set AZURE_SPEECH_KEY=tu_clave_de_azure AZURE_SPEECH_REGION=eastus
supabase functions deploy assess-pronunciation
```

Opcional, para generar lecciones con IA:

```bash
supabase secrets set OPENAI_API_KEY=tu_clave_de_openai
supabase functions deploy generate-lesson
```

### Paso 5. Preparar y correr la app

```bash
cd app
flutter create . --platforms=android,ios --org com.tuempresa   # genera las carpetas android/ e ios/
dart run tool/setup_platforms.dart                              # permisos de micrófono
flutter pub get
```

Copiá `env.example.json` como `env.json` y completá tu URL y anon key de Supabase. Después:

```bash
flutter run --dart-define-from-file=env.json
```

Con un emulador abierto o un celular conectado por USB (con "depuración USB" activada), la app se instala y abre sola.

> **Probalo en un celular real.** El micrófono de los emuladores suele funcionar mal y la evaluación de pronunciación da puntajes bajos.

### Paso 6. Generar el audio nativo (opcional, recomendado)

Sin este paso, la app usa la voz del teléfono para leer los textos. Con este paso usa voces neuronales de Azure, mucho más naturales:

```bash
cd scripts
npm install
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=eastus node generate-audio.mjs
```

La **service role key** está en Supabase → Project Settings → API. Es secreta: usala solo en tu computadora y no la compartas.

### Paso 7. Generar el APK para Android

```bash
cd app
flutter build apk --release --dart-define-from-file=env.json
```

El archivo queda en `app/build/app/outputs/flutter-apk/app-release.apk`. Para publicar en Google Play se usa `flutter build appbundle` y hace falta firmar la app: https://docs.flutter.dev/deployment/android

Para iPhone: `flutter build ipa` desde una Mac con Xcode y una cuenta de Apple Developer. Guía: https://docs.flutter.dev/deployment/ios

---

## Cómo crear más lecciones

**Con IA (recomendado):**

1. En Supabase → Table Editor → `profiles`, marcá `is_admin = true` en tu usuario.
2. Llamá a la función `generate-lesson` (por ejemplo desde Postman o pidiéndole a Claude que te arme el comando) con un brief como:
   ```json
   { "cefr_level": "B1", "context": "work", "topic": "risk",
     "brief": "How to escalate a blocker to the project sponsor" }
   ```
3. La lección queda como borrador. Revisala en el Table Editor y cambiá `published` a `true`.
4. Corré el script de audio para generar su audio nativo.

**A mano:** copiá el formato de cualquier lección de `seed.sql`.

Temas sugeridos para `topic` (coinciden con los intereses del onboarding): `project-management`, `leadership`, `technology`, `digital`, `data`, `productivity`, `communication`, `risk`, `daily-life`, `finance`, `travel`.

---

## Estructura de la app

```
app/lib/
├── main.dart                 # arranque e inicialización de Supabase
├── app.dart                  # rutas (go_router) y tema
├── providers.dart            # estado (Riverpod) y elección de la "Lección de hoy"
├── config/env.dart           # URL y anon key (desde env.json)
├── theme/app_theme.dart      # colores, tipografías, colores de puntaje
├── models/models.dart        # Lesson, QuizQuestion, PronunciationResult, PlayerLevel...
├── services/
│   ├── repository.dart       # todas las llamadas a Supabase
│   └── audio.dart            # grabación WAV 16 kHz y reproducción (audio nativo o TTS)
├── widgets/common.dart       # ScoreRing, ScoredSentence, MicButton, hoja de fonemas
└── screens/                  # una pantalla por archivo
```

## Próximos pasos sugeridos (según el backlog)

1. Test de nivel con lectura en voz alta (E1-4).
2. Login con Google y Apple (E1-1, E1-5).
3. Pantalla "Mis palabras" con repaso de pronunciación (E4-3).
4. Recordatorio diario con notificaciones locales (E8-2).
5. Resaltado tipo karaoke sincronizado con el audio (E2-5).

## Problemas frecuentes

| Problema | Solución |
| --- | --- |
| "Falta la configuración de Supabase" | Estás corriendo sin `--dart-define-from-file=env.json` o el archivo tiene datos vacíos |
| La evaluación devuelve error 500 `azure_not_configured` | Faltan los secretos de Azure: repetí `supabase secrets set ...` y volvé a desplegar la función |
| Error 401 al evaluar | La sesión expiró: cerrá sesión y volvé a entrar |
| "No pudimos escucharte bien" | Hablá más cerca del micrófono y en un lugar sin ruido; revisá el permiso de micrófono |
| No aparecen lecciones | No corriste `seed.sql` o las lecciones tienen `published = false` |
| Error de `minSdk` al compilar Android | Ejecutá `dart run tool/setup_platforms.dart` o poné `minSdk = 23` en `android/app/build.gradle.kts` |
