import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Emite y verifica tokens de acceso (JWT HS256 de vida corta) y genera
/// tokens opacos aleatorios (refresh, restablecimiento de contraseña).
class TokenService {
  final SecretKey _key;
  final Duration accessTokenTtl;
  static const issuer = 'ally';

  TokenService(String secret, {required this.accessTokenTtl})
      : _key = SecretKey(secret);

  String issueAccessToken(String userId) => JWT(
        {'typ': 'access'},
        subject: userId,
        issuer: issuer,
      ).sign(_key, algorithm: JWTAlgorithm.HS256, expiresIn: accessTokenTtl);

  /// Devuelve el ID de usuario o `null` si el token no es válido.
  String? verifyAccessToken(String token) {
    // Se exige HS256 explícitamente (evita ataques de confusión de algoritmo).
    if (_headerAlgorithm(token) != 'HS256') return null;
    try {
      final jwt = JWT.verify(token, _key, issuer: issuer);
      final payload = jwt.payload;
      if (payload is! Map || payload['typ'] != 'access') return null;
      return jwt.subject;
    } on JWTException {
      return null;
    }
  }

  static String? _headerAlgorithm(String token) {
    try {
      final header = token.split('.').first;
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(header))));
      return decoded is Map ? decoded['alg'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  static final _random = Random.secure();

  /// Token aleatorio de 256 bits, apto para URLs.
  static String randomToken([int bytes = 32]) => base64Url
      .encode(List<int>.generate(bytes, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  /// Código legible (sin caracteres ambiguos) para invitaciones.
  static String randomCode([int length = 8]) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(length, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
  }

  /// Los tokens opacos se guardan solo como hash.
  static String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();
}
