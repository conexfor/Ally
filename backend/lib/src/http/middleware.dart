import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../security/token_service.dart';
import 'api_exception.dart';
import 'rate_limiter.dart';
import 'request_utils.dart';

final _log = Logger('http');

/// Convierte cualquier error en una respuesta JSON amigable. Los errores no
/// controlados se registran y se responden con un mensaje genérico.
Middleware errorHandler() => (inner) => (request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        return jsonResponse(e.toBody().toJson(), status: e.status);
      } catch (e, st) {
        _log.severe('Error no controlado en ${request.method} ${request.url}', e, st);
        return jsonResponse(
          const ApiException(500, 'internal_error',
                  'Ocurrió un error inesperado. Inténtalo de nuevo en unos minutos.')
              .toBody()
              .toJson(),
          status: 500,
        );
      }
    };

Middleware requestLogger() => (inner) => (request) async {
      final watch = Stopwatch()..start();
      final response = await inner(request);
      _log.info('${request.method} /${request.url.path} → ${response.statusCode} '
          '(${watch.elapsedMilliseconds} ms)');
      return response;
    };

Middleware securityHeaders() => (inner) => (request) async {
      final response = await inner(request);
      return response.change(headers: {
        'x-content-type-options': 'nosniff',
        'x-frame-options': 'DENY',
        'referrer-policy': 'no-referrer',
        if (!response.headers.containsKey('cache-control')) 'cache-control': 'no-store',
      });
    };

Middleware cors(List<String> allowedOrigins) => (inner) => (request) async {
      final origin = request.headers['origin'];
      final allowed = origin != null && allowedOrigins.contains(origin);
      final headers = allowed
          ? {
              'access-control-allow-origin': origin,
              'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
              'access-control-allow-headers': 'authorization, content-type, x-device-id',
              'vary': 'origin',
            }
          : <String, String>{};
      if (request.method == 'OPTIONS') return Response(204, headers: headers);
      final response = await inner(request);
      return response.change(headers: headers);
    };

/// IP del cliente. `X-Forwarded-For` solo se usa detrás de un proxy de
/// confianza (TRUST_PROXY=true); si no, cualquiera podría falsearla.
String clientIp(Request request, {bool trustProxy = false}) {
  final forwarded = request.headers['x-forwarded-for'];
  if (trustProxy && forwarded != null && forwarded.isNotEmpty) return forwarded.split(',').first.trim();
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
}

/// Límite general por IP y uno más estricto para autenticación (protección
/// contra fuerza bruta).
Middleware rateLimit({
  required RateLimiter general,
  required RateLimiter auth,
  bool trustProxy = false,
}) =>
    (inner) => (request) {
          final ip = clientIp(request, trustProxy: trustProxy);
          final path = request.url.path;
          final isAuth = request.method == 'POST' &&
              ((path.startsWith('api/auth/') && !path.endsWith('refresh')) ||
                  path == 'reset-password' ||
                  path == 'api/me/email/resend');
          final limiter = isAuth ? auth : general;
          final key = isAuth ? 'auth:$ip' : 'all:$ip';
          if (!limiter.tryAcquire(key)) throw const ApiException.tooManyRequests();
          return inner(request);
        };

/// Exige un token de acceso válido salvo en las rutas públicas.
Middleware authentication(TokenService tokens, {required bool Function(Request) isPublic}) =>
    (inner) => (request) {
          if (isPublic(request)) return inner(request);
          final header = request.headers['authorization'] ?? '';
          if (!header.startsWith('Bearer ')) throw const ApiException.unauthorized();
          final userId = tokens.verifyAccessToken(header.substring(7).trim());
          if (userId == null) throw const ApiException.unauthorized();
          return inner(request.change(context: {'auth.userId': userId}));
        };
