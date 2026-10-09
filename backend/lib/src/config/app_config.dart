import 'dart:io';

/// Configuración del servidor leída de variables de entorno (y, en
/// desarrollo, de un archivo `.env`). Ver `.env.example` en la raíz.
class AppConfig {
  final String environment;
  final String host;
  final int port;
  final String databaseUrl;
  final String jwtSecret;
  final Duration accessTokenTtl;
  final Duration refreshTokenTtl;
  final List<String> googleClientIds;
  final List<String> appleClientIds;
  final String? fcmServiceAccountJson;
  final String? fcmProjectId;
  final SmtpConfig? smtp;

  /// Enlace base para restablecer contraseña (se añade `?token=...`).
  final String passwordResetUrl;
  final List<String> corsOrigins;
  final int rateLimitPerMinute;
  final int authRateLimitPerMinute;

  /// El servidor está detrás de un proxy de confianza (usa X-Forwarded-For).
  final bool trustProxy;

  /// URL pública del servidor (para enlaces en correos y páginas web).
  final String publicBaseUrl;

  /// Enlace para verificar el correo (se añade `?token=...`).
  final String emailVerificationUrl;

  /// Android App Links: paquete y huellas SHA-256 del certificado de firma.
  final String? androidPackageName;
  final List<String> androidCertFingerprints;

  /// Enlace a la ficha de Google Play (páginas de invitación).
  final String? playStoreUrl;

  const AppConfig({
    required this.environment,
    required this.host,
    required this.port,
    required this.databaseUrl,
    required this.jwtSecret,
    required this.accessTokenTtl,
    required this.refreshTokenTtl,
    required this.googleClientIds,
    required this.appleClientIds,
    required this.passwordResetUrl,
    required this.corsOrigins,
    required this.rateLimitPerMinute,
    required this.authRateLimitPerMinute,
    this.trustProxy = false,
    this.publicBaseUrl = 'http://localhost:8080',
    this.emailVerificationUrl = 'http://localhost:8080/verify-email',
    this.androidPackageName,
    this.androidCertFingerprints = const [],
    this.playStoreUrl,
    this.fcmServiceAccountJson,
    this.fcmProjectId,
    this.smtp,
  });

  bool get isProduction => environment == 'production';
  bool get pushEnabled => fcmServiceAccountJson != null;

  /// Errores de configuración que impiden arrancar en producción. En
  /// desarrollo se permiten (sin SMTP los correos van al log, HTTP local...).
  List<String> productionProblems() => [
    if (smtp == null) 'SMTP_HOST: sin SMTP los enlaces de recuperación de contraseña se escribirían en el log',
    if (!publicBaseUrl.startsWith('https://')) 'PUBLIC_BASE_URL debe usar https://',
    if (Uri.tryParse(databaseUrl)?.queryParameters['sslmode'] == 'disable')
      'DATABASE_URL: usa sslmode=require o verify-full',
    if (jwtSecret.contains('dev-only') || jwtSecret.contains('cambia'))
      'JWT_SECRET: usa una clave aleatoria propia (openssl rand -base64 48)',
    if (fcmServiceAccountJson == null)
      'FCM_SERVICE_ACCOUNT_FILE / FCM_SERVICE_ACCOUNT_JSON: sin push las alarmas compartidas llegan con retraso',
  ];

  factory AppConfig.fromEnvironment([Map<String, String>? overrides]) {
    final env = {..._loadDotEnv(), ...Platform.environment, ...?overrides};

    String require(String key) {
      final value = env[key];
      if (value == null || value.trim().isEmpty) {
        throw StateError('Falta la variable de entorno obligatoria $key');
      }
      return value.trim();
    }

    String? optional(String key) {
      final value = env[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    List<String> list(String key) =>
        (optional(key) ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final jwtSecret = require('JWT_SECRET');
    if (jwtSecret.length < 32) {
      throw StateError('JWT_SECRET debe tener al menos 32 caracteres');
    }

    String? serviceAccount = optional('FCM_SERVICE_ACCOUNT_JSON');
    final serviceAccountFile = optional('FCM_SERVICE_ACCOUNT_FILE');
    if (serviceAccount == null && serviceAccountFile != null) {
      serviceAccount = File(serviceAccountFile).readAsStringSync();
    }

    final smtpHost = optional('SMTP_HOST');
    final publicBaseUrl = (optional('PUBLIC_BASE_URL') ?? 'http://localhost:${optional('PORT') ?? '8080'}')
        .replaceFirst(RegExp(r'/+$'), '');
    return AppConfig(
      environment: optional('APP_ENV') ?? 'development',
      host: optional('HOST') ?? '0.0.0.0',
      port: int.parse(optional('PORT') ?? '8080'),
      databaseUrl: require('DATABASE_URL'),
      jwtSecret: jwtSecret,
      accessTokenTtl: Duration(minutes: int.parse(optional('ACCESS_TOKEN_TTL_MINUTES') ?? '15')),
      refreshTokenTtl: Duration(days: int.parse(optional('REFRESH_TOKEN_TTL_DAYS') ?? '60')),
      googleClientIds: list('GOOGLE_CLIENT_IDS'),
      appleClientIds: list('APPLE_CLIENT_IDS'),
      fcmServiceAccountJson: serviceAccount,
      fcmProjectId: optional('FCM_PROJECT_ID'),
      smtp: smtpHost == null
          ? null
          : SmtpConfig(
              host: smtpHost,
              port: int.parse(optional('SMTP_PORT') ?? '587'),
              username: optional('SMTP_USERNAME'),
              password: optional('SMTP_PASSWORD'),
              from: optional('SMTP_FROM') ?? 'conexfor@gmail.com',
              ssl: optional('SMTP_SSL') == 'true',
            ),
      passwordResetUrl: optional('PASSWORD_RESET_URL') ?? '$publicBaseUrl/reset-password',
      publicBaseUrl: publicBaseUrl,
      emailVerificationUrl: optional('EMAIL_VERIFICATION_URL') ?? '$publicBaseUrl/verify-email',
      androidPackageName: optional('ANDROID_PACKAGE_NAME'),
      androidCertFingerprints: list('ANDROID_SHA256_CERT_FINGERPRINTS'),
      playStoreUrl: optional('PLAY_STORE_URL'),
      corsOrigins: list('CORS_ORIGINS'),
      rateLimitPerMinute: int.parse(optional('RATE_LIMIT_PER_MINUTE') ?? '120'),
      authRateLimitPerMinute: int.parse(optional('AUTH_RATE_LIMIT_PER_MINUTE') ?? '10'),
      trustProxy: optional('TRUST_PROXY') == 'true',
    );
  }

  /// Lee `.env` del directorio actual o del padre (solo claves no definidas).
  static Map<String, String> _loadDotEnv() {
    for (final path in ['.env', '../.env']) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final result = <String, String>{};
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final index = trimmed.indexOf('=');
        if (index <= 0) continue;
        var value = trimmed.substring(index + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        result[trimmed.substring(0, index).trim()] = value;
      }
      return result;
    }
    return const {};
  }
}

class SmtpConfig {
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String from;
  final bool ssl;

  const SmtpConfig({
    required this.host,
    required this.port,
    required this.from,
    this.username,
    this.password,
    this.ssl = false,
  });
}
