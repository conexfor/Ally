import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

/// Identidad verificada de un proveedor externo.
class ExternalIdentity {
  final String provider;
  final String subject;
  final String? email;
  final bool emailVerified;
  final String? name;

  const ExternalIdentity({
    required this.provider,
    required this.subject,
    this.email,
    this.emailVerified = false,
    this.name,
  });
}

/// Verifica el `id_token` de Google o Apple en el servidor: firma RS256 con
/// las claves públicas del proveedor (JWKS), emisor, audiencia y caducidad.
/// Nunca se confía en datos de identidad enviados por el cliente.
class ExternalIdentityVerifier {
  final http.Client _http;
  final List<String> googleClientIds;
  final List<String> appleClientIds;
  final _cache = <String, _CachedKeys>{};

  ExternalIdentityVerifier({
    required this.googleClientIds,
    required this.appleClientIds,
    http.Client? client,
  }) : _http = client ?? http.Client();

  static const _google = _Provider(
    name: 'google',
    jwksUrl: 'https://www.googleapis.com/oauth2/v3/certs',
    issuers: ['https://accounts.google.com', 'accounts.google.com'],
  );
  static const _apple = _Provider(
    name: 'apple',
    jwksUrl: 'https://appleid.apple.com/auth/keys',
    issuers: ['https://appleid.apple.com'],
  );

  bool get googleEnabled => googleClientIds.isNotEmpty;
  bool get appleEnabled => appleClientIds.isNotEmpty;

  Future<ExternalIdentity?> verifyGoogle(String idToken) =>
      _verify(idToken, _google, googleClientIds);

  Future<ExternalIdentity?> verifyApple(String idToken) =>
      _verify(idToken, _apple, appleClientIds);

  Future<ExternalIdentity?> _verify(
    String token,
    _Provider provider,
    List<String> audiences,
  ) async {
    if (audiences.isEmpty) return null;
    final header = _decodeHeader(token);
    if (header == null || header['alg'] != 'RS256') return null;
    final kid = header['kid'];
    if (kid is! String) return null;

    final key = await _keyFor(provider, kid);
    if (key == null) return null;

    try {
      final jwt = JWT.verify(token, key, checkHeaderType: false);
      final claims = jwt.payload;
      if (claims is! Map) return null;
      if (!provider.issuers.contains(claims['iss'])) return null;
      final aud = claims['aud'];
      final audienceOk = aud is String
          ? audiences.contains(aud)
          : aud is List && aud.any(audiences.contains);
      if (!audienceOk) return null;
      final subject = claims['sub'];
      if (subject is! String || subject.isEmpty) return null;
      final verified = claims['email_verified'];
      return ExternalIdentity(
        provider: provider.name,
        subject: subject,
        email: claims['email'] as String?,
        emailVerified: verified == true || verified == 'true',
        name: claims['name'] as String?,
      );
    } on JWTException {
      return null;
    }
  }

  Future<JWTKey?> _keyFor(_Provider provider, String kid) async {
    var cached = _cache[provider.name];
    if (cached == null || cached.isExpired || !cached.keys.containsKey(kid)) {
      cached = await _fetchKeys(provider);
      if (cached != null) _cache[provider.name] = cached;
    }
    return cached?.keys[kid];
  }

  Future<_CachedKeys?> _fetchKeys(_Provider provider) async {
    try {
      final response = await _http
          .get(Uri.parse(provider.jwksUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final keys = <String, JWTKey>{};
      for (final jwk in (body['keys'] as List).cast<Map<String, dynamic>>()) {
        final kid = jwk['kid'];
        if (kid is String) keys[kid] = JWTKey.fromJWK(jwk);
      }
      return _CachedKeys(keys, DateTime.now().add(const Duration(hours: 6)));
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodeHeader(String token) {
    try {
      final part = token.split('.').first;
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part))));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class _Provider {
  final String name;
  final String jwksUrl;
  final List<String> issuers;
  const _Provider({required this.name, required this.jwksUrl, required this.issuers});
}

class _CachedKeys {
  final Map<String, JWTKey> keys;
  final DateTime expiresAt;
  _CachedKeys(this.keys, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
