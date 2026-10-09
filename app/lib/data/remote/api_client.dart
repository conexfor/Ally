import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ally_core/ally_core.dart';

import '../../core/errors/app_exception.dart';
import 'token_store.dart';

/// Cliente HTTP de la API.
///
/// - Añade el token de acceso y el ID del dispositivo.
/// - Si el token caducó (401), lo renueva una sola vez con el refresh token
///   (las peticiones concurrentes esperan a la misma renovación).
/// - Traduce cualquier error a [AppException] con un mensaje para el usuario.
class ApiClient {
  final Dio _dio;
  final TokenStore tokens;
  String? deviceId;

  /// Se invoca cuando la sesión ya no se puede renovar.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  ApiClient({required String baseUrl, required this.tokens, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              contentType: 'application/json',
              responseType: ResponseType.json,
            ));

  Future<JsonMap> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  Future<JsonMap> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<JsonMap> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<JsonMap> delete(String path) => _send('DELETE', path);

  /// Envía un archivo como cuerpo binario (p. ej. la foto de perfil).
  Future<JsonMap> postBytes(String path, List<int> bytes) => _send('POST', path, bytes: bytes);

  /// URL absoluta de un recurso de la API (p. ej. un avatar).
  String absoluteUrl(String path) => path.startsWith('http') ? path : '${_dio.options.baseUrl}$path';

  /// Cabeceras para cargar recursos protegidos (imágenes).
  Map<String, String> get authHeaders => _headers();

  Future<JsonMap> _send(
    String method,
    String path, {
    Object? body,
    List<int>? bytes,
    Map<String, Object?>? query,
    bool retried = false,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        // El flujo se crea en cada intento (un reintento no puede reutilizarlo).
        data: bytes == null ? body : Stream.value(bytes),
        queryParameters: query == null
            ? null
            : {for (final e in query.entries) if (e.value != null) e.key: e.value},
        options: Options(
          method: method,
          headers: {
            ..._headers(),
            if (bytes != null) 'content-length': '${bytes.length}',
          },
          contentType: bytes == null ? null : 'application/octet-stream',
        ),
      );
      final data = response.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final isAuthPath = path.startsWith('/api/auth/');
      if (status == 401 && !retried && !isAuthPath && tokens.hasSession) {
        if (await _refreshSession()) {
          return _send(method, path, body: body, bytes: bytes, query: query, retried: true);
        }
        onSessionExpired?.call();
      }
      throw _toAppException(e);
    }
  }

  Map<String, String> _headers() => {
        if (tokens.accessToken != null) 'authorization': 'Bearer ${tokens.accessToken}',
        'x-device-id': ?deviceId,
      };

  Future<bool> _refreshSession() {
    return _refreshing ??= () async {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/auth/refresh',
          data: {'refresh_token': tokens.refreshToken},
        );
        final session = AuthSession.fromJson(response.data!);
        await tokens.save(accessToken: session.accessToken, refreshToken: session.refreshToken);
        return true;
      } on DioException catch (e) {
        // Sin red no se cierra la sesión: se reintentará más tarde.
        if (e.response == null) throw _toAppException(e);
        await tokens.clear();
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  static AppException _toAppException(DioException e) {
    final response = e.response;
    if (response == null) return const AppException.network();
    final data = response.data;
    if (data is Map<String, dynamic> && data['error'] is Map) {
      final body = ApiErrorBody.fromJson(data);
      return AppException(body.message, code: body.code, status: response.statusCode, fields: body.fields);
    }
    // Sin el formato de error de la API: la petición no llegó al servidor (página
    // de error de un túnel o proxy, p. ej. ngrok apagado, o un 502/503 del
    // hosting). Se trata como falta de conexión: lo creado se guarda en el
    // teléfono y se envía al volver el servidor, en vez de fallar.
    return const AppException.network();
  }
}
