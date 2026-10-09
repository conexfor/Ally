-- Ally: esquema inicial.
--
-- Convenciones:
--   * IDs UUID (las alarmas pueden traer un ID generado por el cliente para
--     permitir la creación sin conexión e idempotencia).
--   * Todas las fechas en timestamptz (UTC). Las alarmas guardan además su
--     hora de pared + zona horaria para calcular recurrencias.
--   * `sync_version` toma un valor de la secuencia global en cada cambio y es
--     el cursor de sincronización incremental de los clientes.
--   * Los borrados de entidades sincronizadas son lógicos (deleted_at/status)
--     para que los clientes reciban la "lápida".

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SEQUENCE IF NOT EXISTS global_sync_seq;

CREATE OR REPLACE FUNCTION touch_sync_row() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  NEW.sync_version := nextval('global_sync_seq');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------ usuarios

CREATE TABLE users (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username         citext NOT NULL UNIQUE
                   CHECK (username ~ '^[a-z0-9_.]{3,30}$'),
  display_name     text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 60),
  email            citext UNIQUE,
  phone            text UNIQUE,
  avatar_url       text,
  timezone         text NOT NULL DEFAULT 'UTC',
  language         text NOT NULL DEFAULT 'es',
  password_hash    text,
  email_verified_at timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  sync_version     bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  deleted_at       timestamptz
);
CREATE TRIGGER users_touch BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
-- Búsqueda por nombre visible.
CREATE INDEX users_display_name_idx ON users (lower(display_name));

-- Identidades externas (Google, Apple). La identidad interna es users.id.
CREATE TABLE user_identities (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider         text NOT NULL CHECK (provider IN ('google', 'apple')),
  provider_subject text NOT NULL,
  email            citext,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_subject)
);
CREATE INDEX user_identities_user_idx ON user_identities (user_id);

CREATE TABLE user_settings (
  user_id                    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  default_snooze_minutes     int NOT NULL DEFAULT 10 CHECK (default_snooze_minutes BETWEEN 1 AND 1440),
  notify_new_alarms          boolean NOT NULL DEFAULT true,
  notify_responses           boolean NOT NULL DEFAULT true,
  notify_connection_requests boolean NOT NULL DEFAULT true,
  use_24_hour_clock          boolean NOT NULL DEFAULT false,
  updated_at                 timestamptz NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------- dispositivos

CREATE TABLE devices (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name     text NOT NULL CHECK (char_length(device_name) BETWEEN 1 AND 60),
  device_type     text NOT NULL CHECK (device_type IN ('phone', 'tablet', 'computer', 'watch')),
  platform        text NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'other')),
  push_token      text UNIQUE,
  timezone        text NOT NULL DEFAULT 'UTC',
  app_version     text,
  is_active       boolean NOT NULL DEFAULT true,
  receives_alarms boolean NOT NULL DEFAULT true,
  last_seen_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  sync_version    bigint NOT NULL DEFAULT nextval('global_sync_seq')
);
CREATE TRIGGER devices_touch BEFORE UPDATE ON devices
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
CREATE INDEX devices_user_idx ON devices (user_id) WHERE is_active;

-- ------------------------------------------------------- autenticación

CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id   uuid REFERENCES devices(id) ON DELETE SET NULL,
  token_hash  text NOT NULL UNIQUE,   -- SHA-256 del token; el token en claro nunca se guarda
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  replaced_by uuid REFERENCES refresh_tokens(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id) WHERE revoked_at IS NULL;

CREATE TABLE password_reset_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- -------------------------------------------------------------- conexiones

CREATE TABLE connections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  addressee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
  -- Quién bloqueó (solo él puede desbloquear).
  blocked_by   uuid REFERENCES users(id) ON DELETE CASCADE,
  responded_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  sync_version bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  CHECK (requester_id <> addressee_id)
);
CREATE TRIGGER connections_touch BEFORE UPDATE ON connections
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
-- Una sola conexión por par de usuarios, sin importar quién la inició.
CREATE UNIQUE INDEX connections_pair_uq ON connections
  (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));
CREATE INDEX connections_addressee_idx ON connections (addressee_id);
CREATE INDEX connections_requester_idx ON connections (requester_id);

-- Permisos por dirección: owner_id concede a subject_id.
CREATE TABLE connection_permissions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id         uuid NOT NULL REFERENCES connections(id) ON DELETE CASCADE,
  owner_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id            uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  allow_alarms          boolean NOT NULL DEFAULT true,
  auto_accept           boolean NOT NULL DEFAULT false,
  share_response_status boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  sync_version          bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  UNIQUE (connection_id, owner_id),
  UNIQUE (owner_id, subject_id),
  CHECK (owner_id <> subject_id)
);
CREATE TRIGGER connection_permissions_touch BEFORE UPDATE ON connection_permissions
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();

-- Códigos de invitación (texto y QR).
CREATE TABLE invitation_codes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code       text NOT NULL UNIQUE CHECK (code ~ '^[A-Z0-9]{8}$'),
  expires_at timestamptz NOT NULL,
  max_uses   int NOT NULL DEFAULT 20 CHECK (max_uses > 0),
  uses       int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX invitation_codes_user_idx ON invitation_codes (user_id);

-- ------------------------------------------------------------------ grupos

CREATE TABLE groups (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 60),
  description  text CHECK (char_length(description) <= 200),
  owner_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  sync_version bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  deleted_at   timestamptz
);
CREATE TRIGGER groups_touch BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
CREATE INDEX groups_owner_idx ON groups (owner_id);

CREATE TABLE group_members (
  group_id           uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id            uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role               text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  status             text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'active', 'removed')),
  allow_group_alarms boolean NOT NULL DEFAULT true,
  auto_accept        boolean NOT NULL DEFAULT true,
  invited_by         uuid REFERENCES users(id) ON DELETE SET NULL,
  joined_at          timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  sync_version       bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  PRIMARY KEY (group_id, user_id)
);
CREATE TRIGGER group_members_touch BEFORE UPDATE ON group_members
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
CREATE INDEX group_members_user_idx ON group_members (user_id) WHERE status <> 'removed';

-- ----------------------------------------------------------------- alarmas

CREATE TABLE alarms (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title           text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
  message         text CHECK (char_length(message) <= 200),
  -- Primera ocurrencia en hora de pared + zona horaria...
  local_date      date NOT NULL,
  local_time      time NOT NULL,
  timezone        text NOT NULL,
  -- ...y su equivalente UTC.
  scheduled_at    timestamptz NOT NULL,
  -- Próxima ocurrencia pendiente (NULL si ya no sonará más).
  next_occurrence_at timestamptz,
  repeat_rule     jsonb,
  -- Preparado para disparadores por ubicación (no implementados aún).
  trigger_type    text NOT NULL DEFAULT 'time'
                  CHECK (trigger_type IN ('time', 'location_arrive', 'location_leave')),
  status          text NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled', 'triggered', 'completed', 'cancelled', 'snoozed')),
  priority        text NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
  sound           text NOT NULL DEFAULT 'default',
  vibration       boolean NOT NULL DEFAULT true,
  -- El creador decide si los destinatarios ven las respuestas de los demás.
  share_responses boolean NOT NULL DEFAULT true,
  version         int NOT NULL DEFAULT 1,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  sync_version    bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  deleted_at      timestamptz
);
CREATE TRIGGER alarms_touch BEFORE UPDATE ON alarms
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
CREATE INDEX alarms_creator_idx ON alarms (creator_id, next_occurrence_at);
CREATE INDEX alarms_sync_idx ON alarms (sync_version);
CREATE INDEX alarms_due_idx ON alarms (next_occurrence_at)
  WHERE deleted_at IS NULL AND status IN ('scheduled', 'triggered', 'snoozed');

CREATE TABLE alarm_recipients (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alarm_id          uuid NOT NULL REFERENCES alarms(id) ON DELETE CASCADE,
  recipient_type    text NOT NULL CHECK (recipient_type IN ('user', 'group', 'device')),
  recipient_id      uuid NOT NULL,
  -- Usuario que recibe (para 'user' y 'device'); NULL en filas de grupo.
  user_id           uuid REFERENCES users(id) ON DELETE CASCADE,
  -- Si el usuario se añadió por pertenecer a un grupo.
  source_group_id   uuid REFERENCES groups(id) ON DELETE SET NULL,
  permission_status text NOT NULL DEFAULT 'pending'
                    CHECK (permission_status IN ('pending', 'accepted', 'rejected')),
  response_status   text NOT NULL DEFAULT 'no_response'
                    CHECK (response_status IN ('no_response', 'confirmed', 'dismissed', 'snoozed', 'expired')),
  responded_at      timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  sync_version      bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  UNIQUE (alarm_id, recipient_type, recipient_id),
  CHECK (recipient_type = 'group' OR user_id IS NOT NULL)
);
CREATE TRIGGER alarm_recipients_touch BEFORE UPDATE ON alarm_recipients
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
CREATE INDEX alarm_recipients_user_idx ON alarm_recipients (user_id, alarm_id);
CREATE INDEX alarm_recipients_sync_idx ON alarm_recipients (sync_version);

-- En qué dispositivos quiere recibir cada usuario una alarma concreta
-- (por defecto se usa devices.receives_alarms).
CREATE TABLE alarm_device_preferences (
  alarm_id   uuid NOT NULL REFERENCES alarms(id) ON DELETE CASCADE,
  device_id  uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  enabled    boolean NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (alarm_id, device_id)
);

-- Ocurrencias concretas (se crean al responder o al dispararse).
CREATE TABLE alarm_occurrences (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alarm_id      uuid NOT NULL REFERENCES alarms(id) ON DELETE CASCADE,
  scheduled_for timestamptz NOT NULL,
  status        text NOT NULL DEFAULT 'scheduled'
                CHECK (status IN ('scheduled', 'triggered', 'completed', 'cancelled', 'snoozed')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (alarm_id, scheduled_for)
);

CREATE TABLE alarm_responses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurrence_id uuid NOT NULL REFERENCES alarm_occurrences(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id     uuid REFERENCES devices(id) ON DELETE SET NULL,
  response      text NOT NULL CHECK (response IN ('confirmed', 'dismissed', 'snoozed', 'expired')),
  snoozed_until timestamptz,
  responded_at  timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  sync_version  bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  UNIQUE (occurrence_id, user_id)
);
CREATE TRIGGER alarm_responses_touch BEFORE UPDATE ON alarm_responses
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
CREATE INDEX alarm_responses_user_idx ON alarm_responses (user_id, responded_at);
CREATE INDEX alarm_responses_sync_idx ON alarm_responses (sync_version);

-- Alarmas encadenadas (despertar → prepararse → salir...).
CREATE TABLE alarm_sequences (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name         text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 60),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  sync_version bigint NOT NULL DEFAULT nextval('global_sync_seq'),
  deleted_at   timestamptz
);
CREATE TRIGGER alarm_sequences_touch BEFORE UPDATE ON alarm_sequences
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();

CREATE TABLE alarm_sequence_items (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sequence_id uuid NOT NULL REFERENCES alarm_sequences(id) ON DELETE CASCADE,
  alarm_id    uuid NOT NULL REFERENCES alarms(id) ON DELETE CASCADE,
  position    int NOT NULL CHECK (position >= 0),
  UNIQUE (sequence_id, position),
  UNIQUE (alarm_id)
);

-- ---------------------------------------------------------- notificaciones

CREATE TABLE notifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type         text NOT NULL,
  title        text NOT NULL,
  body         text NOT NULL,
  data         jsonb NOT NULL DEFAULT '{}'::jsonb,
  alarm_id     uuid REFERENCES alarms(id) ON DELETE CASCADE,
  -- Evita notificaciones duplicadas (p. ej. "alarm_new:<alarm>:<user>").
  dedupe_key   text NOT NULL UNIQUE,
  read_at      timestamptz,
  pushed_at    timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  sync_version bigint NOT NULL DEFAULT nextval('global_sync_seq')
);
CREATE TRIGGER notifications_touch BEFORE UPDATE ON notifications
  FOR EACH ROW EXECUTE FUNCTION touch_sync_row();
CREATE INDEX notifications_user_idx ON notifications (user_id, created_at DESC);

-- -------------------------------------------------------------------- chat

CREATE TABLE chat_sessions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      text NOT NULL DEFAULT 'Asistente',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX chat_sessions_user_idx ON chat_sessions (user_id, updated_at DESC);

CREATE TABLE chat_messages (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role       text NOT NULL CHECK (role IN ('user', 'system')),
  content    text NOT NULL CHECK (char_length(content) <= 4000),
  payload    jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX chat_messages_session_idx ON chat_messages (session_id, created_at);
