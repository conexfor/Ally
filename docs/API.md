# API REST

Base: `https://<tu-servidor>`. JSON en UTF-8. Autenticación `Authorization: Bearer <access_token>` en todo salvo `/api/auth/*` y `/api/health`. Cabecera opcional `X-Device-Id: <uuid>` para identificar el dispositivo.

Errores: `{"error": {"code": "...", "message": "Mensaje para el usuario", "fields": {"campo": "..."}}}`
Códigos: 400 datos inválidos · 401 sesión · 403 sin permiso · 404 no existe o no es tuyo · 409 conflicto (`version_conflict`, `already_connected`) · 422 validación · 429 límite de peticiones.

Los contratos JSON están definidos en `packages/ally_core/lib/src/api/`.

## Autenticación

| Método | Ruta | Cuerpo / notas |
|---|---|---|
| POST | `/api/auth/register` | `email, password, username, display_name, timezone` → `AuthSession` |
| POST | `/api/auth/login` | `identifier` (correo o usuario), `password` |
| POST | `/api/auth/google` | `id_token, timezone` |
| POST | `/api/auth/apple` | `id_token, full_name?, timezone` |
| POST | `/api/auth/refresh` | `refresh_token` → nueva sesión (rotación) |
| POST | `/api/auth/logout` | `refresh_token` |
| POST | `/api/auth/password/forgot` | `email` (respuesta idéntica exista o no) |
| POST | `/api/auth/password/reset` | `token, password` |
| GET | `/api/auth/username-available?username=` | |

`AuthSession`: `access_token, refresh_token, expires_in, user, is_new_user`.

## Perfil

| GET/PUT | `/api/me` | `display_name, username, phone, timezone, language, avatar_url` |
|---|---|---|
| PUT | `/api/me/password` | `current_password, new_password` |
| DELETE | `/api/me` | elimina la cuenta |
| POST | `/api/me/logout-all` | |
| GET/PUT | `/api/me/settings` | `default_snooze_minutes, notify_*, use_24_hour_clock` |
| GET | `/api/users/search?q=` | `@usuario`, nombre, correo o teléfono exactos |

## Contactos

| GET | `/api/contacts` | lista (`Contact`) |
|---|---|---|
| GET | `/api/contacts/requests` | solicitudes pendientes |
| POST | `/api/contacts/request` | `user_id` \| `username` \| `email` \| `phone` |
| POST | `/api/contacts/{id}/accept` · `/reject` · `/block` · `/unblock` | `{id}` = connection_id |
| DELETE | `/api/contacts/{id}` | |
| PUT | `/api/contacts/{id}/permissions` | `allow_alarms, auto_accept, share_response_status` (lo que YO concedo) |
| POST | `/api/contacts/invitation` | código + `qr_payload` (`ally://connect?code=…`) |
| POST | `/api/contacts/connect` | `code` (texto o contenido del QR) |

## Grupos

| GET/POST | `/api/groups` | `name, description, member_ids` |
|---|---|---|
| GET/PUT/DELETE | `/api/groups/{id}` | |
| POST | `/api/groups/{id}/members` | `user_ids` (deben ser contactos) |
| DELETE | `/api/groups/{id}/members/{userId}` | |
| PUT | `/api/groups/{id}/members/{userId}/role` | `role: admin|member` |
| POST | `/api/groups/{id}/accept` · `/leave` | |
| PUT | `/api/groups/{id}/me` | `allow_group_alarms, auto_accept` |

## Alarmas

| GET | `/api/alarms?scope=all|created|received&from=&to=` | |
|---|---|---|
| POST | `/api/alarms` | `AlarmInput` (el `id` lo puede generar el cliente: idempotente) |
| GET/PUT/DELETE | `/api/alarms/{id}` | PUT con `base_version` (409 si cambió) · DELETE del creador = para todos; del destinatario = dejar de recibir |
| POST | `/api/alarms/{id}/cancel` | cancela la próxima ocurrencia |
| POST | `/api/alarms/{id}/confirm` · `/snooze` · `/dismiss` | `occurrence_at`, `snooze_minutes?` |
| POST | `/api/alarms/{id}/accept` · `/reject` | alarmas pendientes recibidas |
| GET | `/api/alarms/{id}/responses` | según permisos de privacidad |
| PUT | `/api/alarms/{id}/devices/{deviceId}` | `enabled` |
| GET | `/api/alarms/device-preferences` | |

`AlarmInput`:

```json
{
  "id": "uuid opcional",
  "title": "Reunión",
  "message": "Reunión de proyecto",
  "local_date": "2026-10-04",
  "local_time": "08:00",
  "timezone": "America/Bogota",
  "repeat_rule": {"frequency": "weekly", "interval": 1, "days": ["monday", "wednesday"]},
  "priority": "normal | important | urgent",
  "sound": "default | classic | soft",
  "vibration": true,
  "share_responses": true,
  "recipients": [{"type": "user", "id": "…"}, {"type": "group", "id": "…"}, {"type": "device", "id": "…"}],
  "base_version": 3
}
```

## Dispositivos, sincronización y otros

| GET/POST | `/api/devices` | registro idempotente: `id?, device_name, device_type, platform, push_token, timezone, app_version` |
|---|---|---|
| PUT/DELETE | `/api/devices/{id}` | `device_name, receives_alarms` |
| GET | `/api/sync?cursor=N` | `SyncPayload` (ver SINCRONIZACION.md) |
| GET | `/api/notifications` | + `unread` |
| POST | `/api/notifications/{id}/read` · `/read-all` | |
| GET | `/api/history?filter=all|created|received|confirmed|snoozed|cancelled&before=` | |
| GET | `/api/stats?period=month|all` | usuario + grupos |
| POST | `/api/parser/parse` | `{text}` · `{pending, option_id}` · `{pending, text}` → `InterpretationResult` |
| GET/POST | `/api/chat/sessions` · `/api/chat/sessions/{id}/messages` | historial del asistente |
| GET | `/api/health` | |

## Añadido en la versión 1.1

| Método | Ruta | Notas |
|---|---|---|
| POST | `/api/auth/email/verify` | `token` → `UserProfile` (`email_verified: true`) |
| PUT | `/api/me/email` | `email, password` → nuevo correo sin verificar; envía enlace |
| POST | `/api/me/email/resend` | reenvía el enlace (máx. 1 por minuto) |
| POST | `/api/me/avatar` | cuerpo binario JPG/PNG/WebP (≤ 1 MB, tipo detectado por contenido) |
| DELETE | `/api/me/avatar` | |
| GET | `/api/users/{id}/avatar` | solo propio, contactos o miembros de un grupo común |
| GET/POST | `/api/sequences` | rutinas: `name, local_date, timezone, repeat_rule?, recipients, steps[{title, message?, local_time}]` (2–12 pasos, horas crecientes; todo o nada) |
| DELETE | `/api/sequences/{id}` | elimina la rutina y sus alarmas |
| PUT | `/api/groups/{id}` | admite `alarm_policy: members | admins` |

Las alarmas incluyen `sequence_id`, `sequence_name` y `sequence_position` si pertenecen a una rutina; los grupos, `alarm_policy`; el perfil, `email_verified`.

### Páginas web públicas (fuera de `/api`)

| Ruta | Uso |
|---|---|
| `GET/POST /reset-password?token=` | formulario para crear una nueva contraseña (funciona desde cualquier cliente de correo) |
| `GET /verify-email?token=` | confirma el correo |
| `GET /c/{código}` | página de invitación: abre la app o lleva a Google Play |
| `GET /privacy` | política de privacidad |
| `GET /.well-known/assetlinks.json` | verificación de Android App Links |
