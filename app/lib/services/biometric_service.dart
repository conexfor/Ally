import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Bloqueo de la app con la biometría del dispositivo (huella o rostro) y,
/// si el usuario lo prefiere, el PIN/patrón del teléfono como alternativa.
class BiometricService {
  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  BiometricService({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _enabledKey = 'biometric_lock_enabled';

  /// El dispositivo tiene biometría configurada (al menos una huella/rostro).
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEnabled() async => await _storage.read(key: _enabledKey) == 'true';

  Future<void> setEnabled(bool enabled) => enabled
      ? _storage.write(key: _enabledKey, value: 'true')
      : _storage.delete(key: _enabledKey);

  /// Pide la huella. Devuelve `true` si el usuario se autenticó.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Permite usar el PIN del teléfono si la huella falla varias veces.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometría: ${e.code}');
      return false;
    } on LocalAuthException catch (e) {
      debugPrint('Biometría: ${e.code}');
      return false;
    }
  }
}
