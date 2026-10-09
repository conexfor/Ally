/// Configuración de compilación (`--dart-define` o `--dart-define-from-file`).
///
/// Ver `app/env/*.example.json` y el README.
abstract final class Env {
  /// URL base de la API, p. ej. `https://api.tudominio.com`.
  /// Para el emulador de Android contra un backend local: `http://10.0.2.2:8080`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// URL pública de las páginas web (invitaciones, privacidad). Por defecto la
  /// misma que la API.
  static const _publicWebUrl = String.fromEnvironment('PUBLIC_WEB_URL');
  static String get publicWebUrl => (_publicWebUrl.isEmpty ? apiBaseUrl : _publicWebUrl).replaceFirst(RegExp(r'/+$'), '');

  /// Enlace de la ficha en Google Play (para compartir invitaciones).
  static const playStoreUrl = String.fromEnvironment('PLAY_STORE_URL');

  /// ID de cliente OAuth "Web" de Google (para obtener el id_token que
  /// verifica el backend). Vacío = botón de Google oculto.
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Configuración de Firebase (push). Si falta, la app funciona sin push y
  /// sincroniza al abrirse y periódicamente.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static bool get googleSignInConfigured => googleServerClientId.isNotEmpty;
}
