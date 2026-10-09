# Sincronización, modo sin conexión y notificaciones

## Cómo suena una alarma

```text
              Backend (fuente de coordinación)
                       │
          push de datos de alta prioridad (FCM)
             ┌─────────┼─────────┐
             ▼         ▼         ▼
           📱 A      📱 B      💻 C   → sincronizan y PROGRAMAN LOCALMENTE
```

1. El servidor guarda la alarma y avisa a los destinatarios (`alarm_new` / `alarm_request`) con un mensaje **solo de datos** de prioridad alta.
2. El dispositivo sincroniza y `RingPlanner` (núcleo) decide qué ocurrencias deben sonar **en ese dispositivo** durante los próximos 7 días (aceptadas, dispositivo habilitado, sin confirmar, pospuestas reprogramadas).
3. `AlarmScheduler` las programa en el sistema operativo con el plugin `alarm`: suenan con la app cerrada, sin conexión y tras reiniciar el teléfono.
4. Al confirmar/posponer, el cambio se aplica primero en local (deja de sonar al instante) y luego se envía. El servidor avisa a los **otros dispositivos del usuario** (`sync_required`), que sincronizan y cancelan esa ocurrencia: no suena dos veces.

La app no depende de una conexión permanente para que suene una alarma ya programada.

### Responder desde la notificación

La notificación de la alarma tiene el botón **Posponer N min** (N = tu ajuste). No tiene "Detener": para confirmar o descartar se abre la pantalla de la alarma (también al tocar la notificación o con la pantalla completa), y así la respuesta siempre queda registrada. Deslizar la notificación no silencia la alarma.

Si se pospone con la app cerrada, el plugin lo guarda de forma duradera; al abrir la app, `AlarmEventHandler` lo envía al servidor (el creador lo ve y tus otros dispositivos dejan de sonar) y solo entonces lo confirma al plugin. Si el sistema descarta una alarma (por ejemplo, tras reiniciar sin permiso de alarmas exactas), la app te avisa con una notificación.

### Sin la app abierta

Además de los push, una tarea de **WorkManager** sincroniza cada ~15 minutos con conexión y reprograma las alarmas, así un teléfono recibe las alarmas nuevas aunque Firebase no esté configurado o se pierda un push.

## Sincronización incremental

- Cada fila sincronizable tiene `sync_version` (secuencia global de PostgreSQL, actualizada por trigger).
- `GET /api/sync?cursor=N` devuelve alarmas y respuestas con versión > N (incluidas **lápidas**: alarmas eliminadas o en las que dejaste de ser destinatario), notificaciones nuevas y la lista completa de contactos y grupos (son pocos y así reflejan bajas).
- Paginado: si una fuente llena su página, `has_more = true` y el cursor no avanza más allá del último elemento devuelto.
- Disparadores: al iniciar sesión, al volver a la app, cada 3 minutos con la app abierta, al recibir un push y al tirar para refrescar.

## Modo sin conexión

Funciona sin conexión:

- ver alarmas, contactos, grupos y el historial del chat (base de datos local drift/SQLite);
- **crear, editar y eliminar alarmas** (personales o compartidas) — se guardan localmente con un ID generado en el cliente y se encolan;
- confirmar, posponer o descartar alarmas que suenan;
- usar el asistente (el intérprete corre en el dispositivo).

Lo que involucra a otras personas (solicitudes de conexión, grupos) requiere conexión.

### Cola de salida (`outbox_entries`)

Las operaciones se envían **en orden** al recuperar la conexión. Reenviar es seguro: la creación es idempotente por ID y las respuestas son *upserts*.

### Resolución de conflictos

| Situación | Resolución |
|---|---|
| Datos del servidor para una alarma con operaciones locales pendientes | No se sobrescribe hasta enviar la cola. |
| Edición con `base_version` desactualizada (409) en alarma **personal** | Última edición gana: se reaplica sobre la versión actual. |
| Ídem en alarma **compartida** | Gana el servidor; se avisa al usuario en Inicio. |
| El servidor rechaza la operación (4xx) | Se descarta, se revierte localmente y se informa. |
| Error temporal (5xx) o sin red | Se reintenta en la siguiente sincronización. |

## Notificaciones

Tipos: `alarm_new`, `alarm_request`, `alarm_updated`, `alarm_cancelled`, `alarm_confirmed`, `alarm_snoozed`, `alarm_dismissed`, `connection_request`, `connection_accepted`, `group_invitation` y el técnico `sync_required`.

- **Sin duplicados**: cada notificación tiene una `dedupe_key` única (p. ej. `alarm_new:<alarma>:<usuario>`); insertar dos veces no crea ni envía nada nuevo.
- Las de alarmas se envían como datos y la app muestra el aviso localmente (y puede suprimirlo según los ajustes del usuario: `silent`). Las sociales se envían como notificación normal.
- Los tokens que FCM marca como inválidos se eliminan.
- Sin Firebase configurado, la app muestra avisos locales de lo nuevo al sincronizar.

## Configurar Firebase Cloud Messaging

1. Crea un proyecto en <https://console.firebase.google.com> y añade una app **Android** con el `applicationId` (`com.conexfor.ally` o el tuyo).
2. **Backend**: *Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada*. Usa el JSON en `FCM_SERVICE_ACCOUNT_FILE` (o su contenido en `FCM_SERVICE_ACCOUNT_JSON`).
3. **App**: de la configuración de la app Android toma `apiKey`, `appId` (mobilesdk_app_id), `messagingSenderId` (project_number) y `projectId`, y ponlos en `app/env/prod.json` (ver `env/prod.example.json`). No hace falta `google-services.json`: la app inicializa Firebase con estas opciones.
4. iOS (futuro): sube la clave APNs en Firebase y añade una app iOS; el backend no cambia.

## Prioridades

`normal`, `important` y `urgent` cambian el volumen inicial y la rapidez del aumento progresivo del sonido, y se resaltan en la interfaz. **Nunca** se fuerza el volumen ni se salta el modo No molestar ni otras restricciones del sistema.
