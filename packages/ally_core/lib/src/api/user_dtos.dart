import 'json.dart';

/// Datos públicos de otro usuario (lo mínimo para identificarlo).
class PublicUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const PublicUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory PublicUser.fromJson(JsonMap json) => PublicUser(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );

  JsonMap toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
      };
}

/// Perfil completo del usuario autenticado.
class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String timezone;
  final String language;

  /// El correo fue verificado (registro con contraseña o tras cambiarlo).
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.timezone,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.phone,
    this.avatarUrl,
    this.emailVerified = false,
  });

  PublicUser toPublic() => PublicUser(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        timezone: json['timezone'] as String? ?? 'UTC',
        language: json['language'] as String? ?? 'es',
        emailVerified: json['email_verified'] as bool? ?? false,
        createdAt: parseRequiredDateTime(json['created_at']),
        updatedAt: parseRequiredDateTime(json['updated_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'timezone': timezone,
        'language': language,
        'email_verified': emailVerified,
        'created_at': formatDateTime(createdAt),
        'updated_at': formatDateTime(updatedAt),
      };
}

/// Tokens emitidos al iniciar sesión.
class AuthSession {
  final String accessToken;
  final String refreshToken;

  /// Segundos hasta que caduca [accessToken].
  final int expiresIn;
  final UserProfile user;

  /// El usuario acaba de registrarse con un proveedor externo y debería
  /// revisar su nombre de usuario.
  final bool isNewUser;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
    this.isNewUser = false,
  });

  factory AuthSession.fromJson(JsonMap json) => AuthSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresIn: (json['expires_in'] as num).toInt(),
        user: UserProfile.fromJson(json['user'] as JsonMap),
        isNewUser: json['is_new_user'] as bool? ?? false,
      );

  JsonMap toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
        'token_type': 'Bearer',
        'user': user.toJson(),
        'is_new_user': isNewUser,
      };
}

/// Preferencias del usuario.
class UserSettings {
  final int defaultSnoozeMinutes;
  final bool notifyNewAlarms;
  final bool notifyResponses;
  final bool notifyConnectionRequests;
  final bool use24HourClock;

  const UserSettings({
    this.defaultSnoozeMinutes = 10,
    this.notifyNewAlarms = true,
    this.notifyResponses = true,
    this.notifyConnectionRequests = true,
    this.use24HourClock = false,
  });

  factory UserSettings.fromJson(JsonMap json) => UserSettings(
        defaultSnoozeMinutes: (json['default_snooze_minutes'] as num?)?.toInt() ?? 10,
        notifyNewAlarms: json['notify_new_alarms'] as bool? ?? true,
        notifyResponses: json['notify_responses'] as bool? ?? true,
        notifyConnectionRequests: json['notify_connection_requests'] as bool? ?? true,
        use24HourClock: json['use_24_hour_clock'] as bool? ?? false,
      );

  JsonMap toJson() => {
        'default_snooze_minutes': defaultSnoozeMinutes,
        'notify_new_alarms': notifyNewAlarms,
        'notify_responses': notifyResponses,
        'notify_connection_requests': notifyConnectionRequests,
        'use_24_hour_clock': use24HourClock,
      };

  UserSettings copyWith({
    int? defaultSnoozeMinutes,
    bool? notifyNewAlarms,
    bool? notifyResponses,
    bool? notifyConnectionRequests,
    bool? use24HourClock,
  }) =>
      UserSettings(
        defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
        notifyNewAlarms: notifyNewAlarms ?? this.notifyNewAlarms,
        notifyResponses: notifyResponses ?? this.notifyResponses,
        notifyConnectionRequests:
            notifyConnectionRequests ?? this.notifyConnectionRequests,
        use24HourClock: use24HourClock ?? this.use24HourClock,
      );
}
