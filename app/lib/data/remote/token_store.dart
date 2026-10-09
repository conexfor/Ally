import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda los tokens de sesión en el almacenamiento seguro del sistema
/// (Keystore en Android, Keychain en iOS).
class TokenStore {
  final FlutterSecureStorage _storage;
  String? _accessToken;
  String? _refreshToken;

  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> load() async {
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _refreshToken != null;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
