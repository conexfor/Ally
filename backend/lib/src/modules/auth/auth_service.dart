import 'package:logging/logging.dart';
import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../../security/external_identity_verifier.dart';
import '../../security/password_hasher.dart';
import '../../security/token_service.dart';
import '../notifications/email_sender.dart';
import '../users/users_repository.dart';

class RegisterInput {
  final String email;
  final String password;
  final String username;
  final String displayName;
  final String timezone;
  final String language;

  const RegisterInput({
    required this.email,
    required this.password,
    required this.username,
    required this.displayName,
    this.timezone = 'UTC',
    this.language = 'es',
  });

  factory RegisterInput.fromJson(JsonMap json) => RegisterInput(
        email: Validators.normalizeEmail(json['email'] as String? ?? ''),
        password: json['password'] as String? ?? '',
        username: Validators.normalizeUsername(json['username'] as String? ?? ''),
        displayName: (json['display_name'] as String? ?? '').trim(),
        timezone: json['timezone'] as String? ?? 'UTC',
        language: json['language'] as String? ?? 'es',
      );
}

/// Registro, inicio de sesión, renovación y cierre de sesión.
///
/// - Tokens de acceso JWT de vida corta.
/// - Refresh tokens opacos, guardados como hash y rotados en cada uso; si se
///   reutiliza uno ya rotado (posible robo) se revoca toda la familia.
class AuthService {
  final Db db;
  final UsersRepository users;
  final PasswordHasher hasher;
  final TokenService tokens;
  final ExternalIdentityVerifier identities;
  final EmailSender email;
  final Duration refreshTokenTtl;
  final String passwordResetUrl;
  final String emailVerificationUrl;
  final _log = Logger('AuthService');

  AuthService({
    required this.db,
    required this.users,
    required this.hasher,
    required this.tokens,
    required this.identities,
    required this.email,
    required this.refreshTokenTtl,
    required this.passwordResetUrl,
    required this.emailVerificationUrl,
  });

  static const _invalidCredentials = ApiException(
    401,
    'invalid_credentials',
    'El correo/usuario o la contraseña no son correctos.',
  );

  Future<AuthSession> register(RegisterInput input, {String? deviceId}) async {
    final errors = FieldErrors()
      ..check('email', Validators.email(input.email))
      ..check('password', Validators.password(input.password))
      ..check('username', Validators.username(input.username))
      ..check('display_name', Validators.displayName(input.displayName));
    if (!ZonedSchedule.isValidTimezone(input.timezone)) {
      errors.add('timezone', 'La zona horaria no es válida.');
    }
    errors.throwIfAny();

    if (await users.findByEmail(input.email) != null) {
      throw ApiException.validation({'email': 'Ya existe una cuenta con este correo.'});
    }
    if (await users.usernameExists(input.username)) {
      throw ApiException.validation({'username': 'Ese nombre de usuario ya está en uso.'});
    }

    final hash = await hasher.hash(input.password);
    final UserProfile user;
    try {
      user = await users.create(
        username: input.username,
        displayName: input.displayName,
        email: input.email,
        passwordHash: hash,
        timezone: input.timezone,
        language: input.language,
      );
    } catch (e) {
      if (isUniqueViolation(e)) {
        throw ApiException.validation({'username': 'Ese correo o usuario ya está en uso.'});
      }
      rethrow;
    }
    await _sendVerification(user.id, input.email, user.displayName);
    return _issueSession(user, deviceId: deviceId);
  }

  Future<AuthSession> login(String identifier, String password, {String? deviceId}) async {
    final found = await users.findForLogin(identifier);
    // Se verifica igualmente un hash para que el tiempo de respuesta no
    // revele si el usuario existe.
    final hash = found?.passwordHash ?? await (_dummyHash ??= hasher.hash('timing-equalizer-1'));
    final ok = await hasher.verify(password, hash);
    if (found == null || found.passwordHash == null || !ok) throw _invalidCredentials;
    return _issueSession(found.user, deviceId: deviceId);
  }

  Future<String>? _dummyHash;

  Future<AuthSession> loginWithGoogle(String idToken, {String timezone = 'UTC', String? deviceId}) async {
    if (!identities.googleEnabled) {
      throw const ApiException(503, 'provider_disabled', 'El inicio de sesión con Google no está disponible.');
    }
    final identity = await identities.verifyGoogle(idToken);
    if (identity == null) throw const ApiException.unauthorized('No pudimos verificar tu cuenta de Google.');
    return _loginWithIdentity(identity, timezone: timezone, deviceId: deviceId);
  }

  Future<AuthSession> loginWithApple(
    String idToken, {
    String? fullName,
    String timezone = 'UTC',
    String? deviceId,
  }) async {
    if (!identities.appleEnabled) {
      throw const ApiException(503, 'provider_disabled', 'El inicio de sesión con Apple no está disponible.');
    }
    final identity = await identities.verifyApple(idToken);
    if (identity == null) throw const ApiException.unauthorized('No pudimos verificar tu cuenta de Apple.');
    return _loginWithIdentity(
      ExternalIdentity(
        provider: identity.provider,
        subject: identity.subject,
        email: identity.email,
        emailVerified: identity.emailVerified,
        // Apple solo envía el nombre en el primer inicio, desde el cliente.
        name: fullName ?? identity.name,
      ),
      timezone: timezone,
      deviceId: deviceId,
    );
  }

  Future<AuthSession> _loginWithIdentity(
    ExternalIdentity identity, {
    required String timezone,
    String? deviceId,
  }) async {
    final linked = await db.one(
      'SELECT user_id::text AS user_id FROM user_identities '
      'WHERE provider = @p AND provider_subject = @s',
      {'p': identity.provider, 's': identity.subject},
    );
    if (linked != null) {
      final user = await users.findById(linked['user_id'] as String);
      if (user == null) throw const ApiException.unauthorized();
      return _issueSession(user, deviceId: deviceId);
    }

    // Solo se vincula a una cuenta existente si el proveedor verificó el correo.
    UserProfile? user;
    var isNew = false;
    if (identity.email != null && identity.emailVerified) {
      user = await users.findByEmail(identity.email!);
    }
    if (user == null) {
      isNew = true;
      user = await users.create(
        username: await _generateUsername(identity),
        displayName: _displayNameFor(identity),
        email: identity.emailVerified ? identity.email : null,
        timezone: ZonedSchedule.isValidTimezone(timezone) ? timezone : 'UTC',
        emailVerified: identity.emailVerified,
      );
    }
    await db.execute(
      'INSERT INTO user_identities (user_id, provider, provider_subject, email) '
      'VALUES (@u::uuid, @p, @s, @e::citext) ON CONFLICT (provider, provider_subject) DO NOTHING',
      {'u': user.id, 'p': identity.provider, 's': identity.subject, 'e': identity.email},
    );
    return _issueSession(user, deviceId: deviceId, isNewUser: isNew);
  }

  String _displayNameFor(ExternalIdentity identity) {
    final name = identity.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name.length > Validators.maxDisplayNameLength
          ? name.substring(0, Validators.maxDisplayNameLength)
          : name;
    }
    return identity.email?.split('@').first ?? 'Usuario';
  }

  Future<String> _generateUsername(ExternalIdentity identity) async {
    final source = identity.email?.split('@').first ?? identity.name ?? 'usuario';
    var base = TextNormalizer.foldWithSameLength(source)
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (base.length < 3) base = 'usuario';
    if (base.length > 24) base = base.substring(0, 24);
    if (!await users.usernameExists(base)) return base;
    for (var i = 0; i < 20; i++) {
      final candidate = '${base}_${TokenService.randomCode(4).toLowerCase()}';
      if (!await users.usernameExists(candidate)) return candidate;
    }
    return 'user_${TokenService.randomCode(10).toLowerCase()}';
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final hash = TokenService.hashToken(refreshToken);
    // La revocación por reutilización debe confirmarse aunque la petición
    // falle, por eso la transacción devuelve null en lugar de lanzar.
    final session = await db.transaction<AuthSession?>((tx) async {
      final row = await tx.one(
        'SELECT id::text AS id, user_id::text AS user_id, device_id::text AS device_id, '
        'expires_at, revoked_at FROM refresh_tokens WHERE token_hash = @h FOR UPDATE',
        {'h': hash},
      );
      if (row == null) throw const ApiException.unauthorized();
      final userId = row['user_id'] as String;
      if (row['revoked_at'] != null) {
        // Reutilización de un token ya rotado: se revocan todas las sesiones.
        _log.warning('Reutilización de refresh token detectada para $userId');
        await tx.execute(
          'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = @u::uuid AND revoked_at IS NULL',
          {'u': userId},
        );
        return null;
      }
      if ((row['expires_at'] as DateTime).isBefore(DateTime.now().toUtc())) {
        throw const ApiException.unauthorized();
      }
      final user = await UsersRepository(tx).findById(userId);
      if (user == null) throw const ApiException.unauthorized();

      final session = await _issueSession(user, deviceId: row['device_id'] as String?, db: tx);
      await tx.execute(
        'UPDATE refresh_tokens SET revoked_at = now(), '
        'replaced_by = (SELECT id FROM refresh_tokens WHERE token_hash = @new) '
        'WHERE id = @id::uuid',
        {'id': row['id'], 'new': TokenService.hashToken(session.refreshToken)},
      );
      return session;
    });
    return session ?? (throw const ApiException.unauthorized());
  }

  Future<void> logout(String refreshToken) => db.execute(
        'UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = @h AND revoked_at IS NULL',
        {'h': TokenService.hashToken(refreshToken)},
      );

  Future<void> logoutEverywhere(String userId) => db.execute(
        'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = @u::uuid AND revoked_at IS NULL',
        {'u': userId},
      );

  Future<void> changePassword(String userId, String current, String next) async {
    final row = await db.one(
      'SELECT password_hash FROM users WHERE id = @id::uuid',
      {'id': userId},
    );
    final hash = row?['password_hash'] as String?;
    if (hash != null && !await hasher.verify(current, hash)) {
      throw ApiException.validation({'current_password': 'La contraseña actual no es correcta.'});
    }
    final error = Validators.password(next);
    if (error != null) throw ApiException.validation({'new_password': error});
    await users.setPassword(userId, await hasher.hash(next));
  }

  /// Siempre responde igual exista o no la cuenta (no revela correos).
  Future<void> requestPasswordReset(String emailAddress) async {
    final user = await users.findByEmail(Validators.normalizeEmail(emailAddress));
    if (user == null || user.email == null) return;
    final token = TokenService.randomToken();
    await db.execute(
      'INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) '
      "VALUES (@u::uuid, @h, now() + interval '1 hour')",
      {'u': user.id, 'h': TokenService.hashToken(token)},
    );
    final link = '$passwordResetUrl?token=$token';
    await email.send(
      to: user.email!,
      subject: 'Restablece tu contraseña de Ally',
      text: 'Hola ${user.displayName},\n\n'
          'Para crear una nueva contraseña abre este enlace desde tu teléfono '
          '(caduca en 1 hora):\n\n$link\n\n'
          'Si no lo solicitaste, ignora este mensaje.',
    );
  }

  Future<void> resetPassword(String token, String newPassword) async {
    final error = Validators.password(newPassword);
    if (error != null) throw ApiException.validation({'password': error});
    final hash = await hasher.hash(newPassword);
    await db.transaction((tx) async {
      final row = await tx.one(
        'UPDATE password_reset_tokens SET used_at = now() '
        'WHERE token_hash = @h AND used_at IS NULL AND expires_at > now() '
        'RETURNING user_id::text AS user_id',
        {'h': TokenService.hashToken(token)},
      );
      if (row == null) {
        throw const ApiException.badRequest(
          'El enlace no es válido o ya caducó. Solicita uno nuevo.',
          code: 'invalid_reset_token',
        );
      }
      final userId = row['user_id'] as String;
      await UsersRepository(tx).setPassword(userId, hash);
      await tx.execute(
        'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = @u::uuid AND revoked_at IS NULL',
        {'u': userId},
      );
    });
  }

  // ------------------------------------------------------- verificación de correo

  Future<void> _sendVerification(String userId, String email, String name, {Db? db}) async {
    final token = TokenService.randomToken();
    await (db ?? this.db).execute(
      'INSERT INTO email_verification_tokens (user_id, email, token_hash, expires_at) '
      "VALUES (@u::uuid, @e::citext, @h, now() + interval '48 hours')",
      {'u': userId, 'e': email, 'h': TokenService.hashToken(token)},
    );
    await this.email.send(
      to: email,
      subject: 'Confirma tu correo en Ally',
      text: 'Hola $name,\n\nConfirma tu correo abriendo este enlace (caduca en 48 horas):\n\n'
          '$emailVerificationUrl?token=$token\n\nSi no creaste una cuenta, ignora este mensaje.',
    );
  }

  /// Marca el correo como verificado. Devuelve el usuario o lanza si el enlace
  /// no es válido. Solo verifica si el correo sigue siendo el mismo.
  Future<UserProfile> verifyEmail(String token) async {
    final row = await db.one(
      '''
      WITH used AS (
        UPDATE email_verification_tokens SET used_at = now()
        WHERE token_hash = @h AND used_at IS NULL AND expires_at > now()
        RETURNING user_id, email
      )
      UPDATE users u SET email_verified_at = now()
      FROM used WHERE u.id = used.user_id AND u.email = used.email
      RETURNING u.id::text AS id
      ''',
      {'h': TokenService.hashToken(token)},
    );
    if (row == null) {
      throw const ApiException.badRequest(
        'El enlace no es válido o ya caducó. Solicita uno nuevo desde la app.',
        code: 'invalid_verification_token',
      );
    }
    return (await users.findById(row['id'] as String))!;
  }

  Future<void> resendVerification(String userId) async {
    final user = await users.findById(userId);
    if (user == null || user.email == null) throw const ApiException.notFound();
    if (user.emailVerified) return;
    final recent = await db.one(
      "SELECT 1 FROM email_verification_tokens WHERE user_id = @u::uuid AND created_at > now() - interval '1 minute'",
      {'u': userId},
    );
    if (recent != null) {
      throw const ApiException(429, 'rate_limited', 'Espera un minuto antes de pedir otro correo.');
    }
    await _sendVerification(userId, user.email!, user.displayName);
  }

  /// Cambia el correo (requiere la contraseña si la cuenta tiene una). El
  /// nuevo correo queda sin verificar hasta abrir el enlace.
  Future<UserProfile> changeEmail(String userId, String newEmail, String password) async {
    final email = Validators.normalizeEmail(newEmail);
    final error = Validators.email(email);
    if (error != null) throw ApiException.validation({'email': error});
    final row = await db.one('SELECT password_hash FROM users WHERE id = @id::uuid', {'id': userId});
    final hash = row?['password_hash'] as String?;
    if (hash != null && !await hasher.verify(password, hash)) {
      throw ApiException.validation({'password': 'La contraseña no es correcta.'});
    }
    final existing = await users.findByEmail(email);
    if (existing != null && existing.id != userId) {
      throw ApiException.validation({'email': 'Ya existe una cuenta con este correo.'});
    }
    await db.execute(
      'UPDATE users SET email = @e::citext, email_verified_at = NULL WHERE id = @id::uuid',
      {'e': email, 'id': userId},
    );
    final user = (await users.findById(userId))!;
    await _sendVerification(userId, email, user.displayName);
    return user;
  }

  Future<AuthSession> _issueSession(
    UserProfile user, {
    String? deviceId,
    bool isNewUser = false,
    Db? db,
  }) async {
    final refreshToken = TokenService.randomToken();
    await (db ?? this.db).execute(
      'INSERT INTO refresh_tokens (user_id, device_id, token_hash, expires_at) '
      'VALUES (@u::uuid, (SELECT id FROM devices WHERE id = @d::uuid AND user_id = @u::uuid), @h, @exp)',
      {
        'u': user.id,
        'd': deviceId,
        'h': TokenService.hashToken(refreshToken),
        'exp': DateTime.now().toUtc().add(refreshTokenTtl),
      },
    );
    return AuthSession(
      accessToken: tokens.issueAccessToken(user.id),
      refreshToken: refreshToken,
      expiresIn: tokens.accessTokenTtl.inSeconds,
      user: user,
      isNewUser: isNewUser,
    );
  }
}
