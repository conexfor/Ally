/// Utilidades de lectura de JSON con tipos estrictos.
library;

typedef JsonMap = Map<String, dynamic>;

DateTime? parseDateTime(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

DateTime parseRequiredDateTime(Object? value) =>
    DateTime.parse(value as String).toUtc();

String? formatDateTime(DateTime? value) => value?.toUtc().toIso8601String();

List<T> parseList<T>(Object? value, T Function(JsonMap) fromJson) => [
      for (final item in (value as List? ?? const []))
        fromJson(item as JsonMap),
    ];

/// Error estándar de la API: `{"error": {"code", "message", "fields"}}`.
class ApiErrorBody {
  final String code;
  final String message;
  final Map<String, String> fields;

  const ApiErrorBody(this.code, this.message, {this.fields = const {}});

  factory ApiErrorBody.fromJson(JsonMap json) {
    final error = json['error'] as JsonMap? ?? json;
    return ApiErrorBody(
      error['code'] as String? ?? 'unknown',
      error['message'] as String? ?? 'Ocurrió un error inesperado.',
      fields: Map<String, String>.from(error['fields'] as Map? ?? const {}),
    );
  }

  JsonMap toJson() => {
        'error': {
          'code': code,
          'message': message,
          if (fields.isNotEmpty) 'fields': fields,
        },
      };
}
