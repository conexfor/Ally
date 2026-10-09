import 'dart:convert';
import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';

/// Hash de contraseñas con bcrypt.
///
/// La contraseña se pre-procesa con SHA-256 para que bcrypt (que solo usa
/// los primeros 72 bytes) tenga en cuenta contraseñas largas. El cálculo se
/// hace en otro isolate para no bloquear el servidor.
class PasswordHasher {
  final int cost;
  const PasswordHasher({this.cost = 12});

  static String _prehash(String password) =>
      base64.encode(sha256.convert(utf8.encode(password)).bytes);

  Future<String> hash(String password) {
    final cost = this.cost;
    return Isolate.run(
      () => BCrypt.hashpw(_prehash(password), BCrypt.gensalt(logRounds: cost)),
    );
  }

  Future<bool> verify(String password, String hash) => Isolate.run(() {
        try {
          return BCrypt.checkpw(_prehash(password), hash);
        } catch (_) {
          return false;
        }
      });
}
