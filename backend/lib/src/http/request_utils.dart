import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:ally_core/ally_core.dart';

import 'api_exception.dart';

const _maxBodyBytes = 64 * 1024;

Response jsonResponse(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response noContent() => Response(204);

extension RequestUtils on Request {
  /// ID del usuario autenticado (lo fija el middleware de autenticación).
  String get userId {
    final id = context['auth.userId'] as String?;
    if (id == null) throw const ApiException.unauthorized();
    return id;
  }

  /// Dispositivo desde el que se hace la petición (cabecera X-Device-Id).
  String? get deviceId {
    final id = headers['x-device-id'];
    return Validators.isUuid(id) ? id : null;
  }

  /// Cuerpo binario con límite de tamaño (p. ej. una foto).
  Future<List<int>> readBytes(int maxBytes) async {
    final length = contentLength;
    if (length != null && length > maxBytes) {
      throw const ApiException(413, 'payload_too_large', 'El archivo es demasiado grande.');
    }
    final bytes = <int>[];
    await for (final chunk in read()) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) {
        throw const ApiException(413, 'payload_too_large', 'El archivo es demasiado grande.');
      }
    }
    return bytes;
  }

  Future<JsonMap> readJson() async {
    final length = contentLength;
    if (length != null && length > _maxBodyBytes) {
      throw const ApiException(413, 'payload_too_large', 'La solicitud es demasiado grande.');
    }
    final bytes = <int>[];
    await for (final chunk in read()) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBodyBytes) {
        throw const ApiException(413, 'payload_too_large', 'La solicitud es demasiado grande.');
      }
    }
    if (bytes.isEmpty) return {};
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on FormatException {
      throw const ApiException.badRequest('El contenido de la solicitud no es válido.');
    }
  }

  /// Lee y convierte el cuerpo; cualquier error de formato es un 400.
  Future<T> readBody<T>(T Function(JsonMap json) parse) async {
    final json = await readJson();
    try {
      return parse(json);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException.badRequest('Faltan datos o tienen un formato no válido.');
    }
  }

  String? query(String name) {
    final value = url.queryParameters[name]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  int queryInt(String name, {required int defaultValue, int? min, int? max}) {
    final raw = query(name);
    var value = raw == null ? defaultValue : int.tryParse(raw) ?? defaultValue;
    if (min != null && value < min) value = min;
    if (max != null && value > max) value = max;
    return value;
  }
}

/// Valida que un parámetro de ruta sea un UUID (evita errores de SQL y
/// enumeración de IDs con formatos inesperados).
String requireUuid(String? value) {
  if (!Validators.isUuid(value)) throw const ApiException.notFound();
  return value!.toLowerCase();
}
