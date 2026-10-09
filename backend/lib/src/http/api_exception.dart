import 'package:ally_core/ally_core.dart';

/// Error controlado de la API. El mensaje siempre es apto para el usuario
/// final; nunca se exponen detalles técnicos.
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final Map<String, String> fields;

  const ApiException(this.status, this.code, this.message, {this.fields = const {}});

  const ApiException.badRequest(String message, {String code = 'bad_request'})
      : this(400, code, message);

  ApiException.validation(Map<String, String> fields)
      : this(
          422,
          'validation_failed',
          fields.values.first,
          fields: fields,
        );

  const ApiException.unauthorized([String message = 'Tu sesión expiró. Inicia sesión de nuevo.'])
      : this(401, 'unauthorized', message);

  const ApiException.forbidden([String message = 'No tienes permiso para realizar esta acción.'])
      : this(403, 'forbidden', message);

  /// Se usa también cuando el recurso existe pero no pertenece al usuario,
  /// para no revelar su existencia.
  const ApiException.notFound([String message = 'No encontramos lo que buscas.'])
      : this(404, 'not_found', message);

  const ApiException.conflict(String message, {String code = 'conflict'})
      : this(409, code, message);

  const ApiException.tooManyRequests()
      : this(429, 'rate_limited', 'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.');

  ApiErrorBody toBody() => ApiErrorBody(code, message, fields: fields);

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// Acumula errores de validación por campo.
class FieldErrors {
  final _errors = <String, String>{};

  void check(String field, String? error) {
    if (error != null) _errors.putIfAbsent(field, () => error);
  }

  void add(String field, String message) => _errors.putIfAbsent(field, () => message);

  void throwIfAny() {
    if (_errors.isNotEmpty) throw ApiException.validation(Map.of(_errors));
  }
}
