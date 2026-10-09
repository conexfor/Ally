# Ally

**Alarmas compartidas y sincronizadas entre personas y dispositivos**, con un asistente que entiende lenguaje natural en español **sin usar inteligencia artificial**.

> "Crea una alarma mañana a las 8 para Juan que diga reunión de proyecto."
>
> ⏰ 08:00 AM · 📅 Mañana · 👤 Juan · 📝 Reunión de proyecto — *¿Quieres crearla?*

Juan la recibe, su teléfono la hace sonar (aunque no tenga conexión en ese momento), confirma, y tú ves **Juan 🟢 Confirmó**.

Aplicación multiplataforma en **Flutter** (Android; iOS preparado) con backend en **Dart + PostgreSQL**. La primera publicación está pensada para Google Play.

---

## Características

- **Asistente conversacional por reglas**: horas, fechas, recurrencias, varios destinatarios, grupos, mensajes, consultas, edición, cancelación y posposición. Pregunta cuando hay ambigüedad (AM/PM, varios "Carlos", contacto inexistente) y **siempre pide confirmación** antes de modificar datos. Funciona sin conexión. Ver [docs/PARSER.md](docs/PARSER.md) y [ejemplos](docs/EJEMPLOS_DE_COMANDOS.md).
- **Formulario manual** para crear y editar alarmas (título, mensaje, fecha, hora, destinatarios, grupos, recurrencia, prioridad, sonido, vibración, dispositivos).
- **Usuarios y contactos**: registro con correo, Google (y Apple en iOS); búsqueda por @usuario, nombre, correo o teléfono; solicitudes (aceptar/rechazar/bloquear); **código QR** e invitación por código.
- **Permisos por contacto**: permitir alarmas, aceptarlas automáticamente, permitir ver confirmaciones.
- **Grupos** con invitaciones, roles y permisos de cada miembro.
- **Respuestas**: confirmar, posponer (5/10/15/30 min o personalizado), descartar; estado por destinatario y por ocurrencia.
- **Varios dispositivos** por cuenta, con elección de dónde suena cada alarma; lo que respondes en uno se refleja en los demás.
- **Sincronización incremental** y **modo sin conexión** con cola de operaciones y resolución de conflictos.
- **Notificaciones push** (FCM) sin duplicados; avisos locales si Firebase no está configurado.
- **Historial** con filtros y paginación; **estadísticas** personales y de grupo con reparto de respuestas.
- **Rutinas (alarmas encadenadas)**: 07:00 Despertar → 07:15 Prepararse → 07:30 Salir de casa, creadas y eliminadas juntas.
- **Foto de perfil**, verificación y cambio de correo, recuperación de contraseña con página web propia, invitaciones compartibles por enlace.
- **Posponer desde la notificación** aunque la app esté cerrada (se registra al volver a abrirla) y aviso si el sistema no pudo hacer sonar una alarma.
- **Grupos** con opción "solo administradores envían alarmas".
- **Seguridad**: JWT de vida corta + refresh rotado, bcrypt, verificación de Google/Apple en el servidor, autorización por recurso, rate limiting, validación server-side, eliminación de cuenta.

## Arquitectura

```text
nueva_app/
├── packages/ally_core/   Dart puro compartido: dominio, contratos API, recurrencias,
│                              zonas horarias, validaciones y motor NLP por reglas
├── backend/                   API REST: shelf + PostgreSQL (migraciones SQL)
├── app/                       App Flutter: Riverpod, go_router, drift (SQLite), FCM, alarmas nativas
├── docs/                      Documentación
├── docker-compose.yml         PostgreSQL + API para desarrollo
└── .env.example               Variables de entorno del backend
```

Detalles: [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) · API: [docs/API.md](docs/API.md) · Sincronización y push: [docs/SINCRONIZACION_Y_NOTIFICACIONES.md](docs/SINCRONIZACION_Y_NOTIFICACIONES.md)

## Tecnologías

| Parte | Tecnologías |
|---|---|
| App | Flutter 3.44 / Dart 3.12, Riverpod 3, go_router, drift + SQLite, dio, flutter_secure_storage, `alarm` (alarmas nativas), flutter_local_notifications, Firebase Messaging, google_sign_in, sign_in_with_apple, mobile_scanner, qr_flutter |
| Backend | Dart 3.12, shelf, shelf_router, postgres 3, dart_jsonwebtoken, bcrypt, googleapis_auth (FCM HTTP v1), mailer, timezone |
| Base de datos | PostgreSQL 14+ (probado con 17) |
| Núcleo | Dart puro (`meta`, `timezone`) |

## Requisitos

- Flutter 3.44+ (incluye Dart 3.12)
- PostgreSQL 14+ (o Docker)
- Android SDK (para compilar la app)

## Instalación y ejecución local

### 1. Base de datos y backend

Con Docker:

```bash
docker compose up -d          # PostgreSQL en :5432 y API en :8080
curl http://localhost:8080/api/health
```

Sin Docker (PostgreSQL propio):

```bash
cd backend
cp ../.env.example .env       # edita DATABASE_URL y JWT_SECRET
dart pub get
dart run bin/migrate.dart     # aplica migraciones (también se aplican al arrancar)
dart run bin/server.dart      # API en http://localhost:8080
```

### 2. App

```bash
cd app
flutter pub get
dart run build_runner build   # genera el código de drift (ya incluido en el repo)
cp env/dev.example.json env/dev.json
flutter run --dart-define-from-file=env/dev.json
```

`API_BASE_URL` por defecto es `http://10.0.2.2:8080` (el `localhost` del PC visto desde el emulador de Android). En un teléfono físico usa la IP de tu PC en la red local o una URL pública con HTTPS.

## Variables de entorno

Backend: ver [.env.example](.env.example) (todas comentadas). Obligatorias: `DATABASE_URL` y `JWT_SECRET` (≥ 32 caracteres aleatorios).

App (`--dart-define` o `--dart-define-from-file`):

| Variable | Uso |
|---|---|
| `API_BASE_URL` | URL de la API |
| `GOOGLE_SERVER_CLIENT_ID` | ID de cliente OAuth **Web** de Google (vacío = sin botón de Google) |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID` | Push; vacías = sin push (la app sigue funcionando) |

## Configuración de integraciones externas

Estas integraciones no se pueden configurar automáticamente; el código está completo y solo requiere credenciales:

- **Notificaciones push (FCM)**: [docs/SINCRONIZACION_Y_NOTIFICACIONES.md](docs/SINCRONIZACION_Y_NOTIFICACIONES.md#configurar-firebase-cloud-messaging).
- **Inicio de sesión con Google**: en Google Cloud Console crea un cliente OAuth **Android** (paquete `com.conexfor.ally` + SHA-1 de tu clave de firma) y un cliente **Web**. Usa el ID del cliente Web en `GOOGLE_SERVER_CLIENT_ID` (app) y en `GOOGLE_CLIENT_IDS` (backend).
- **Apple** (iOS, futuro): activa *Sign in with Apple* en el identificador de la app y pon el bundle id en `APPLE_CLIENT_IDS`.
- **Correo** (recuperar contraseña): variables `SMTP_*`. Sin SMTP el enlace aparece en el log del servidor.

## Tests

```bash
# Núcleo: motor NLP, recurrencias, zonas horarias, planificación de sonidos (200 tests)
cd packages/ally_core && dart test

# Backend: integración contra PostgreSQL real (flujo completo, seguridad, permisos,
# grupos, QR, sincronización, refresh tokens, recuperación de contraseña) + unitarios
cd backend
TEST_DATABASE_URL=postgresql://usuario:clave@localhost:5432/ally_test?sslmode=disable dart test --concurrency=1

# App: sincronización offline/conflictos y ejecución de comandos
cd app && flutter test
```

> ⚠️ La base de datos de `TEST_DATABASE_URL` se **borra** en cada ejecución. Usa una base dedicada.

Tests de la app en un dispositivo o emulador (incluye un flujo completo contra el backend local):

```bash
cd app && flutter test integration_test -d <dispositivo> --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

> **Windows con Control de aplicaciones inteligente**: si Windows bloquea `flutter_tester.exe`, `flutter test` no funciona en el PC (usa el comando anterior en un dispositivo). Si bloquea `font-subset.exe` al compilar en *release*, añade `--no-tree-shake-icons` (la app ocupa unos KB más).

## Base de datos

- Esquema y comentarios: `backend/migrations/0001_initial_schema.sql`.
- Nuevas migraciones: añade `backend/migrations/0002_descripcion.sql`; se aplican en orden, una vez, cada una en su transacción (tabla `schema_migrations`).

## Publicar en Google Play

1. El `applicationId` es `com.conexfor.ally` (no se puede cambiar tras publicar). Úsalo también en Firebase y en Google Cloud (OAuth).
2. Crea una clave de firma: `keytool -genkey -v -keystore ~/ally.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ally`.
3. Crea `app/android/key.properties` (no se sube al repositorio):
   ```properties
   storeFile=C:/ruta/ally.jks
   storePassword=...
   keyAlias=ally
   keyPassword=...
   ```
4. Dominio de los enlaces (App Links): en `app/android/gradle.properties` añade `ally.appLinkHost=api.tu-dominio.com`, y en el backend `PUBLIC_BASE_URL=https://api.tu-dominio.com`, `ANDROID_PACKAGE_NAME` y `ANDROID_SHA256_CERT_FINGERPRINTS` (huella SHA-256 de *Play Console → Integridad de la app*). El servidor publica `/.well-known/assetlinks.json`.
5. `flutter build appbundle --release --dart-define-from-file=env/prod.json`
6. Ficha de Play Console:
   - **Icono**: `app/assets/branding/play_store_icon.png` (512×512). Se regenera con `dart run tool/generate_icons.dart`.
   - **Política de privacidad**: `https://<tu-dominio>/privacy`. Antes de publicar, completa los datos del responsable en `backend/lib/src/modules/web/privacy_policy.dart` y revísala legalmente.
   - **Seguridad de los datos**: declara nombre, correo, teléfono (opcional), foto (opcional), contactos dentro de la app, contenido de alarmas y mensajes del asistente, identificadores del dispositivo (token push). Cifrado en tránsito: sí. Eliminación: desde la app (*Perfil → Configuración → Eliminar mi cuenta*) y en `https://<tu-dominio>/privacy`.
   - **Permisos sensibles**: declara **alarmas exactas** (`USE_EXACT_ALARM`: la función principal de la app es de alarma) y **notificaciones en pantalla completa**.

## Estructura del proyecto

```text
app/lib/
  app/            arranque, providers, rutas
  application/    sesión, chat del asistente, ejecución de comandos
  core/           configuración, tema, widgets comunes, formato
  data/           API, base de datos local, repositorios
  features/       pantallas (auth, home, assistant, alarms, people, groups, profile)
  services/       sincronización, alarmas nativas, push, notificaciones, dispositivo
backend/lib/src/
  config/ db/ http/ security/ modules/{auth,users,contacts,groups,alarms,devices,notifications,sync,parser,chat}
packages/ally_core/lib/src/
  domain/ api/ scheduling/ validation/ nlp/{lexicon,parsers,model,resolution}
```

## Cómo funciona el parser

Resumen: normaliza el texto, extrae el mensaje, detecta el intent con reglas de prioridad, extrae recurrencia, horas, fechas y destinatarios (cada parser consume lo que reconoce), resuelve contra tus contactos/grupos/alarmas, valida, pregunta lo que falte y genera la confirmación. Todo detallado en [docs/PARSER.md](docs/PARSER.md), incluido **cómo agregar nuevas reglas y nuevos intents**.

## Cómo extender el sistema

- **IA opcional**: implementar `CommandInterpreter` con otra clase; nada más depende del intérprete concreto.
- **Alarmas por ubicación**: `alarms.trigger_type` ya admite `location_arrive/location_leave`; falta un módulo de geocercas en la app y un `RingPlanner` para ese tipo.
- **Alarmas encadenadas**: tablas `alarm_sequences` y `alarm_sequence_items` listas para un endpoint que cree la secuencia.
- **Calendarios, Slack, Teams, WhatsApp, wearables**: nuevos módulos del backend que usen `AlarmsService` (permisos y notificaciones incluidos).
- **Varias instancias del backend**: sustituir `RateLimiter` en memoria por uno compartido (Redis) y ejecutar `AlarmMaintenanceJob` en una sola instancia.

## Limitaciones conocidas

- iOS: el código y las dependencias son multiplataforma, pero falta configurar el proyecto iOS (APNs, capacidades, *Sign in with Apple*) y probar en dispositivo. Las alarmas en segundo plano en iOS tienen restricciones del sistema.
- Las alarmas recurrentes se programan con 7 días de antelación; se reprograman al abrir la app, al recibir un push y cada ~15 minutos en segundo plano (WorkManager) cuando hay conexión.
- La interfaz y el asistente están solo en español.
