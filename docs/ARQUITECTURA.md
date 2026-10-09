# Arquitectura

Ally es un monorepo **Dart de extremo a extremo**:

```text
nueva_app/
├── packages/ally_core/   Dart puro, compartido por app y backend
│   ├── domain/       enums, LocalDate/LocalTime, RepeatRule
│   ├── api/          contratos JSON (DTOs) de la API
│   ├── scheduling/   recurrencias, zonas horarias, RingPlanner
│   ├── validation/   reglas de validación compartidas
│   └── nlp/          motor de lenguaje natural por reglas (ver PARSER.md)
├── backend/                   API REST (shelf + PostgreSQL)
└── app/                       App Flutter (Android; iOS preparado)
```

Compartir el núcleo garantiza que el asistente se comporte igual en el teléfono (sin conexión) y en `POST /api/parser/parse`, y que app y servidor validen y serialicen exactamente igual.

## Capas de la app (`app/lib/`)

| Capa | Carpeta | Contenido |
|---|---|---|
| UI | `features/`, `core/widgets`, `core/theme` | Pantallas y componentes. Sin lógica de negocio. |
| Aplicación | `application/` | `SessionController`, `ChatController`, `CommandExecutor`, constructor de contexto. |
| Dominio | `ally_core` | Reglas de negocio puras (parser, recurrencias, planificación de sonidos). |
| Infraestructura | `data/remote`, `services/` | Cliente HTTP, push (FCM), notificaciones locales, alarmas nativas. |
| Base de datos local | `data/local/` | drift (SQLite): alarmas, respuestas, cola offline, chat… |
| Sincronización | `services/sync_engine.dart` | Cola de salida + descarga incremental + conflictos. |
| Repositorios | `data/repositories/` | Offline-first; los usa tanto la UI como el asistente. |

Estado con **Riverpod**, navegación con **go_router**. Las dependencias se crean en `AppServices` (sin widgets), lo que permite reutilizarlas en el isolate de mensajes push en segundo plano.

## Capas del backend (`backend/lib/src/`)

```text
config/      AppConfig (variables de entorno)
db/          Database (pool, transacciones), Migrator
http/        middleware: errores, CORS, cabeceras de seguridad, rate limit, autenticación
security/    bcrypt, JWT (HS256 estricto), verificación de id_token de Google/Apple (JWKS)
modules/
  auth/          registro, login, refresh con rotación, recuperación de contraseña
  users/         perfil, ajustes, búsqueda, eliminación de cuenta
  contacts/      conexiones, permisos por dirección, bloqueo, códigos QR
  groups/        grupos, invitaciones, roles, permisos del miembro
  alarms/        alarmas, destinatarios, respuestas, historial, estadísticas, job de mantenimiento
  devices/       dispositivos y tokens push
  notifications/ bandeja, deduplicación, FCM, correo
  sync/          sincronización incremental por cursor
  parser/        intérprete expuesto por API (contexto construido en el servidor)
  chat/          sesiones y mensajes del asistente
```

## Modelo de datos

Ver `backend/migrations/0001_initial_schema.sql` (comentado). Tablas: `users`, `user_identities`, `user_settings`, `devices`, `refresh_tokens`, `password_reset_tokens`, `connections`, `connection_permissions`, `invitation_codes`, `groups`, `group_members`, `alarms`, `alarm_recipients`, `alarm_device_preferences`, `alarm_occurrences`, `alarm_responses`, `alarm_sequences`, `alarm_sequence_items`, `notifications`, `chat_sessions`, `chat_messages`.

Decisiones clave:

- **Identidad interna = UUID**. Correo, teléfono, Google o Apple son formas de entrar (`user_identities`).
- **Alarmas en hora de pared + zona horaria** (`local_date`, `local_time`, `timezone`) y su equivalente UTC. Las recurrencias se calculan en hora local, por lo que una alarma diaria a las 08:00 sigue a las 08:00 tras un cambio de horario.
- **Destinatarios formales** (`alarm_recipients`): tipo `user`, `group` o `device`. Un grupo se expande a filas de usuario con `source_group_id`, cada una con su `permission_status` y `response_status`.
- **Respuestas por ocurrencia** (`alarm_occurrences` + `alarm_responses`): en una alarma diaria cada día tiene sus propias confirmaciones.
- **Permisos por dirección** (`connection_permissions.owner_id` concede a `subject_id`): permitir alarmas, aceptar automáticamente, compartir confirmación.
- **Borrado lógico** y `sync_version` (secuencia global) para la sincronización incremental.
- **Secuencias encadenadas** (`alarm_sequences`, `alarm_sequence_items`) modeladas para alarmas consecutivas.
- **Ubicación**: `alarms.trigger_type` admite `location_arrive` / `location_leave`, preparado para una fase futura (no implementado en el MVP; el planificador solo programa disparadores de tiempo).

## Seguridad

- Contraseñas con bcrypt (coste 12, pre-hash SHA-256 para no truncar a 72 bytes), verificación en un isolate y tiempo constante aunque el usuario no exista.
- Access token JWT de 15 min (se exige `alg=HS256`), refresh token opaco guardado como hash, rotado en cada uso; reutilizar uno ya rotado revoca todas las sesiones.
- `id_token` de Google/Apple verificado en el servidor (firma RS256 con JWKS, emisor, audiencia, caducidad).
- Autorización en cada operación: la alarma solo es visible para su creador y destinatarios; cambiar un ID devuelve 404. Editar/eliminar exige ser el creador.
- Validación server-side de todos los datos (las mismas reglas que la app).
- Rate limiting general y estricto para autenticación; tamaño máximo de petición; IDs validados como UUID; SQL siempre parametrizado.
- Cabeceras de seguridad, CORS por lista blanca, errores sin detalles técnicos.
- En el teléfono los tokens van en Keystore/Keychain (`flutter_secure_storage`).
- Privacidad: el creador ve respuestas solo de quien se lo permite; los destinatarios ven las de los demás solo si el creador lo permite (`share_responses`). Búsqueda por correo/teléfono solo exacta. Eliminación de cuenta disponible (requisito de Google Play).

## Escalabilidad y extensiones futuras

- `CommandInterpreter` permite añadir un intérprete con IA opcional sin cambiar la app.
- `PushSender`, `EmailSender` y `RateLimiter` son interfaces: se pueden sustituir (APNs directo, SES, Redis).
- `trigger_type` y `alarm_sequences` preparan ubicación y alarmas encadenadas.
- Integraciones (Google Calendar, Outlook, Slack, Teams, WhatsApp, wearables) pueden añadirse como nuevos módulos del backend que creen alarmas a través de `AlarmsService`, reutilizando permisos y notificaciones.
