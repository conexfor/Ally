import 'package:backend/src/db/migrator.dart';
import 'package:backend/src/http/rate_limiter.dart';
import 'package:backend/src/security/token_service.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  group('TokenService', () {
    final tokens = TokenService('a' * 40, accessTokenTtl: const Duration(minutes: 15));

    test('emite y verifica tokens de acceso', () {
      final token = tokens.issueAccessToken('user-1');
      expect(tokens.verifyAccessToken(token), 'user-1');
    });

    test('rechaza tokens firmados con otra clave', () {
      final other = TokenService('b' * 40, accessTokenTtl: const Duration(minutes: 15));
      expect(tokens.verifyAccessToken(other.issueAccessToken('user-1')), isNull);
    });

    test('rechaza el algoritmo "none" y tokens de otro tipo', () {
      final none = JWT({'typ': 'access'}, subject: 'x', issuer: TokenService.issuer)
          .sign(SecretKey('a' * 40), algorithm: JWTAlgorithm.HS512);
      expect(tokens.verifyAccessToken(none), isNull);
      final refreshLike = JWT({'typ': 'refresh'}, subject: 'x', issuer: TokenService.issuer)
          .sign(SecretKey('a' * 40));
      expect(tokens.verifyAccessToken(refreshLike), isNull);
      expect(tokens.verifyAccessToken('basura'), isNull);
    });

    test('tokens aleatorios y códigos', () {
      expect(TokenService.randomToken(), isNot(TokenService.randomToken()));
      expect(TokenService.randomCode(), matches(RegExp(r'^[A-Z0-9]{8}$')));
      expect(TokenService.hashToken('x'), hasLength(64));
    });
  });

  test('RateLimiter limita por clave dentro de la ventana', () {
    var now = DateTime(2026, 1, 1, 10);
    final limiter = RateLimiter(maxRequests: 2, now: () => now);
    expect(limiter.tryAcquire('a'), isTrue);
    expect(limiter.tryAcquire('a'), isTrue);
    expect(limiter.tryAcquire('a'), isFalse);
    expect(limiter.tryAcquire('b'), isTrue);
    now = now.add(const Duration(minutes: 2));
    expect(limiter.tryAcquire('a'), isTrue);
  });

  test('splitSqlStatements respeta funciones y cadenas', () {
    const sql = '''
      -- comentario; con punto y coma
      CREATE TABLE a (x text DEFAULT 'a;b');
      CREATE FUNCTION f() RETURNS trigger AS \$\$ BEGIN RETURN NEW; END; \$\$ LANGUAGE plpgsql;
      SELECT 1
    ''';
    final statements = splitSqlStatements(sql);
    expect(statements, hasLength(3));
    expect(statements[1], contains('RETURN NEW; END;'));
    expect(statements[0], contains("'a;b'"));
  });
}
