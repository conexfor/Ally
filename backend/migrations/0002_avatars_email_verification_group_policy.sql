-- Fotos de perfil, verificación de correo, política de alarmas de grupo y
-- recordatorio de alarmas encadenadas.

-- Foto de perfil (pequeña, ya redimensionada por la app).
CREATE TABLE user_avatars (
  user_id      uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
  data         bytea NOT NULL CHECK (octet_length(data) <= 1048576),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- Verificación de correo (también al cambiarlo).
CREATE TABLE email_verification_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email      citext NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX email_verification_tokens_user_idx ON email_verification_tokens (user_id);

-- Quién puede enviar alarmas al grupo: todos los miembros o solo administradores.
ALTER TABLE groups
  ADD COLUMN alarm_policy text NOT NULL DEFAULT 'members'
  CHECK (alarm_policy IN ('members', 'admins'));

-- Hora de cada paso de una secuencia relativa al primero (informativa).
ALTER TABLE alarm_sequence_items
  ADD COLUMN offset_minutes int NOT NULL DEFAULT 0 CHECK (offset_minutes >= 0);
CREATE INDEX alarm_sequences_owner_idx ON alarm_sequences (owner_id) WHERE deleted_at IS NULL;
