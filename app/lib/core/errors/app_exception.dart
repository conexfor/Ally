/// Error con un mensaje apto para mostrar al usuario. La interfaz nunca
/// muestra excepciones técnicas.
class AppException implements Exception {
  final String message;
  final String code;
  final int? status;
  final Map<String, String> fields;

  const AppException(
    this.message, {
    this.code = 'unknown',
    this.status,
    this.fields = const {},
  });

  const AppException.network()
      : this(
          'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.',
          code: 'network',
        );

  const AppException.unexpected()
      : this('Ocurrió un error inesperado. Inténtalo de nuevo.', code: 'unexpected');

  bool get isNetwork => code == 'network';
  bool get isUnauthorized => status == 401;
  bool get isConflict => status == 409;

  /// Errores del cliente (4xx) que no se resolverán reintentando.
  bool get isPermanent => status != null && status! >= 400 && status! < 500 && status != 408 && status != 429;

  @override
  String toString() => message;
}

/// Convierte cualquier error en un mensaje para el usuario.
String userMessage(Object error) =>
    error is AppException ? error.message : const AppException.unexpected().message;
