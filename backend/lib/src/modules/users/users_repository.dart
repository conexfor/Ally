import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';

/// Columnas públicas de `users` (nunca incluye password_hash).
const userColumns =
    'u.id::text AS id, u.username::text AS username, u.display_name, u.email::text AS email, '
    'u.phone, u.avatar_url, u.timezone, u.language, u.created_at, u.updated_at, '
    '(u.email_verified_at IS NOT NULL) AS email_verified';

UserProfile userFromRow(Row row) => UserProfile(
      id: row['id'] as String,
      username: row['username'] as String,
      displayName: row['display_name'] as String,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      timezone: row['timezone'] as String,
      language: row['language'] as String,
      emailVerified: row['email_verified'] as bool? ?? false,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );

/// Extrae un [PublicUser] de columnas con prefijo (`<prefix>_id`, ...).
PublicUser publicUserFromRow(Row row, [String prefix = 'user']) => PublicUser(
      id: row['${prefix}_id'] as String,
      username: row['${prefix}_username'] as String,
      displayName: row['${prefix}_display_name'] as String,
      avatarUrl: row['${prefix}_avatar_url'] as String?,
    );

/// SQL para seleccionar un usuario público con prefijo desde el alias [alias].
String publicUserColumns(String alias, [String prefix = 'user']) =>
    '$alias.id::text AS ${prefix}_id, $alias.username::text AS ${prefix}_username, '
    '$alias.display_name AS ${prefix}_display_name, $alias.avatar_url AS ${prefix}_avatar_url';

class UserWithPassword {
  final UserProfile user;
  final String? passwordHash;
  const UserWithPassword(this.user, this.passwordHash);
}

class UsersRepository {
  final Db db;
  UsersRepository(this.db);

  Future<UserProfile?> findById(String id) async {
    final row = await db.one(
      'SELECT $userColumns FROM users u WHERE u.id = @id::uuid AND u.deleted_at IS NULL',
      {'id': id},
    );
    return row == null ? null : userFromRow(row);
  }

  /// Busca por correo o nombre de usuario (para iniciar sesión).
  Future<UserWithPassword?> findForLogin(String identifier) async {
    final row = await db.one(
      'SELECT $userColumns, u.password_hash FROM users u '
      'WHERE (u.email = @v::citext OR u.username = @v::citext) AND u.deleted_at IS NULL',
      {'v': identifier.trim().replaceFirst(RegExp(r'^@'), '')},
    );
    return row == null
        ? null
        : UserWithPassword(userFromRow(row), row['password_hash'] as String?);
  }

  Future<UserProfile?> findByEmail(String email) async {
    final row = await db.one(
      'SELECT $userColumns FROM users u WHERE u.email = @e::citext AND u.deleted_at IS NULL',
      {'e': email},
    );
    return row == null ? null : userFromRow(row);
  }

  Future<UserProfile?> findByUsername(String username) async {
    final row = await db.one(
      'SELECT $userColumns FROM users u WHERE u.username = @u::citext AND u.deleted_at IS NULL',
      {'u': Validators.normalizeUsername(username)},
    );
    return row == null ? null : userFromRow(row);
  }

  Future<UserProfile?> findByPhone(String phone) async {
    final row = await db.one(
      'SELECT $userColumns FROM users u WHERE u.phone = @p AND u.deleted_at IS NULL',
      {'p': Validators.normalizePhone(phone)},
    );
    return row == null ? null : userFromRow(row);
  }

  Future<bool> usernameExists(String username) async =>
      await db.one('SELECT 1 FROM users WHERE username = @u::citext', {'u': username}) != null;

  Future<UserProfile> create({
    required String username,
    required String displayName,
    String? email,
    String? passwordHash,
    String timezone = 'UTC',
    String language = 'es',
    bool emailVerified = false,
  }) async {
    final row = await db.one(
      '''
      WITH inserted AS (
        INSERT INTO users (username, display_name, email, password_hash, timezone, language, email_verified_at)
        VALUES (@username::citext, @display_name, @email::citext, @password_hash, @timezone, @language,
                CASE WHEN @verified::boolean THEN now() END)
        RETURNING *
      ), settings AS (
        INSERT INTO user_settings (user_id) SELECT id FROM inserted
      )
      SELECT $userColumns FROM inserted u
      ''',
      {
        'username': username,
        'display_name': displayName,
        'email': email,
        'password_hash': passwordHash,
        'timezone': timezone,
        'language': language,
        'verified': emailVerified,
      },
    );
    return userFromRow(row!);
  }

  Future<UserProfile> updateProfile(
    String id, {
    String? displayName,
    String? username,
    String? phone,
    bool clearPhone = false,
    String? avatarUrl,
    String? timezone,
    String? language,
  }) async {
    final row = await db.one(
      '''
      UPDATE users u SET
        display_name = COALESCE(@display_name, display_name),
        username     = COALESCE(@username::citext, username),
        phone        = CASE WHEN @clear_phone::boolean THEN NULL ELSE COALESCE(@phone, phone) END,
        avatar_url   = COALESCE(@avatar_url, avatar_url),
        timezone     = COALESCE(@timezone, timezone),
        language     = COALESCE(@language, language)
      WHERE u.id = @id::uuid AND u.deleted_at IS NULL
      RETURNING $userColumns
      ''',
      {
        'id': id,
        'display_name': displayName,
        'username': username,
        'phone': phone,
        'clear_phone': clearPhone,
        'avatar_url': avatarUrl,
        'timezone': timezone,
        'language': language,
      },
    );
    return userFromRow(row!);
  }

  Future<void> setPassword(String id, String passwordHash) => db.execute(
        'UPDATE users SET password_hash = @h WHERE id = @id::uuid',
        {'id': id, 'h': passwordHash},
      );

  /// Búsqueda de usuarios para conectar. Correo y teléfono solo coinciden de
  /// forma exacta (no se permite descubrir correos por prefijo).
  Future<List<PublicUser>> search(String query, {required String excludeUserId, int limit = 20}) async {
    final q = query.trim();
    final rows = await db.query(
      '''
      SELECT ${publicUserColumns('u')}
      FROM users u
      WHERE u.deleted_at IS NULL AND u.id <> @me::uuid
        AND (
          u.username ILIKE @prefix
          OR lower(u.display_name) LIKE lower(@contains)
          OR u.email = @exact::citext
          OR u.phone = @phone
        )
        AND NOT EXISTS (
          SELECT 1 FROM connections c
          WHERE c.status = 'blocked'
            AND ((c.requester_id = u.id AND c.addressee_id = @me::uuid)
              OR (c.addressee_id = u.id AND c.requester_id = @me::uuid))
        )
      ORDER BY (u.username = @exact::citext) DESC, u.username
      LIMIT @limit
      ''',
      {
        'me': excludeUserId,
        'prefix': '${_escapeLike(Validators.normalizeUsername(q))}%',
        'contains': '%${_escapeLike(q)}%',
        'exact': q.replaceFirst(RegExp(r'^@'), ''),
        'phone': Validators.normalizePhone(q),
        'limit': limit,
      },
    );
    return [for (final r in rows) publicUserFromRow(r)];
  }

  Future<UserSettings> getSettings(String userId) async {
    final row = await db.one(
      'SELECT * FROM user_settings WHERE user_id = @id::uuid',
      {'id': userId},
    );
    if (row == null) return const UserSettings();
    return UserSettings.fromJson(row);
  }

  Future<UserSettings> saveSettings(String userId, UserSettings s) async {
    final row = await db.one(
      '''
      INSERT INTO user_settings (user_id, default_snooze_minutes, notify_new_alarms, notify_responses,
                                 notify_connection_requests, use_24_hour_clock, updated_at)
      VALUES (@id::uuid, @snooze, @new_alarms, @responses, @requests, @h24, now())
      ON CONFLICT (user_id) DO UPDATE SET
        default_snooze_minutes = EXCLUDED.default_snooze_minutes,
        notify_new_alarms = EXCLUDED.notify_new_alarms,
        notify_responses = EXCLUDED.notify_responses,
        notify_connection_requests = EXCLUDED.notify_connection_requests,
        use_24_hour_clock = EXCLUDED.use_24_hour_clock,
        updated_at = now()
      RETURNING *
      ''',
      {
        'id': userId,
        'snooze': s.defaultSnoozeMinutes,
        'new_alarms': s.notifyNewAlarms,
        'responses': s.notifyResponses,
        'requests': s.notifyConnectionRequests,
        'h24': s.use24HourClock,
      },
    );
    return UserSettings.fromJson(row!);
  }

  /// Elimina la cuenta: borra datos personales y desactiva el acceso. Las
  /// alarmas creadas se eliminan en cascada.
  Future<void> deleteAccount(String userId) => db.transaction((tx) async {
        await tx.execute('DELETE FROM alarms WHERE creator_id = @id::uuid', {'id': userId});
        await tx.execute('DELETE FROM users WHERE id = @id::uuid', {'id': userId});
      });
}

String _escapeLike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// Foto de perfil guardada en la base de datos (imágenes pequeñas).
class AvatarRepository {
  final Db db;
  AvatarRepository(this.db);

  static const maxBytes = 1024 * 1024;

  /// Detecta el tipo real por los primeros bytes (no se confía en la cabecera).
  static String? detectContentType(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  /// Guarda la foto y actualiza `avatar_url` (con versión para invalidar cachés).
  Future<String> save(String userId, String contentType, List<int> bytes) => db.transaction((tx) async {
        await tx.execute(
          '''
          INSERT INTO user_avatars (user_id, content_type, data, updated_at)
          VALUES (@u::uuid, @t, @d::bytea, now())
          ON CONFLICT (user_id) DO UPDATE SET content_type = EXCLUDED.content_type,
            data = EXCLUDED.data, updated_at = now()
          ''',
          {'u': userId, 't': contentType, 'd': bytes},
        );
        final url = '/api/users/$userId/avatar?v=${DateTime.now().millisecondsSinceEpoch}';
        await tx.execute('UPDATE users SET avatar_url = @url WHERE id = @u::uuid', {'u': userId, 'url': url});
        return url;
      });

  Future<void> remove(String userId) => db.transaction((tx) async {
        await tx.execute('DELETE FROM user_avatars WHERE user_id = @u::uuid', {'u': userId});
        await tx.execute('UPDATE users SET avatar_url = NULL WHERE id = @u::uuid', {'u': userId});
      });

  /// Foto visible para [viewerId]: la propia, la de un contacto o la de alguien
  /// con quien comparte grupo (no se exponen fotos de desconocidos).
  Future<({String contentType, List<int> bytes})?> load(String viewerId, String userId) async {
    final row = await db.one(
      '''
      SELECT a.content_type, a.data FROM user_avatars a
      WHERE a.user_id = @u::uuid AND (
        @u::uuid = @me::uuid
        OR EXISTS (SELECT 1 FROM connections c
                   WHERE c.status IN ('accepted', 'pending')
                     AND ((c.requester_id = @me::uuid AND c.addressee_id = @u::uuid)
                       OR (c.addressee_id = @me::uuid AND c.requester_id = @u::uuid)))
        OR EXISTS (SELECT 1 FROM group_members m1 JOIN group_members m2 ON m1.group_id = m2.group_id
                   WHERE m1.user_id = @me::uuid AND m2.user_id = @u::uuid
                     AND m1.status <> 'removed' AND m2.status <> 'removed')
      )
      ''',
      {'u': userId, 'me': viewerId},
    );
    if (row == null) return null;
    return (contentType: row['content_type'] as String, bytes: row['data'] as List<int>);
  }
}
