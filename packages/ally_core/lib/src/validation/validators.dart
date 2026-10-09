/// Reglas de validación compartidas por la app (formularios) y el backend
/// (validación server-side). Devuelven `null` si el valor es válido o un
/// mensaje apto para el usuario.
abstract final class Validators {
  static final _username = RegExp(r'^[a-z0-9_.]{3,30}$');
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _phone = RegExp(r'^\+?[0-9]{7,15}$');
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static const minPasswordLength = 8;
  static const maxPasswordLength = 128;
  static const maxDisplayNameLength = 60;
  static const maxTitleLength = 80;
  static const maxMessageLength = 200;
  static const maxGroupNameLength = 60;
  static const maxGroupDescriptionLength = 200;
  static const maxDeviceNameLength = 60;
  static const maxRecipients = 50;

  /// Normaliza un nombre de usuario: minúsculas, sin `@` inicial.
  static String normalizeUsername(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s\-().]'), '');

  static String? username(String? value) {
    final v = normalizeUsername(value ?? '');
    if (v.isEmpty) return 'Elige un nombre de usuario.';
    if (!_username.hasMatch(v)) {
      return 'El usuario debe tener entre 3 y 30 caracteres: letras minúsculas, '
          'números, punto o guion bajo.';
    }
    return null;
  }

  static String? email(String? value) {
    final v = normalizeEmail(value ?? '');
    if (v.isEmpty) return 'Escribe tu correo electrónico.';
    if (v.length > 254 || !_email.hasMatch(v)) return 'El correo no es válido.';
    return null;
  }

  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _phone.hasMatch(normalizePhone(value))
        ? null
        : 'El número de teléfono no es válido.';
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.length < minPasswordLength) {
      return 'La contraseña debe tener al menos $minPasswordLength caracteres.';
    }
    if (v.length > maxPasswordLength) return 'La contraseña es demasiado larga.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'La contraseña debe incluir letras y números.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Escribe tu nombre.';
    if (v.length > maxDisplayNameLength) {
      return 'El nombre puede tener como máximo $maxDisplayNameLength caracteres.';
    }
    return null;
  }

  static String? alarmTitle(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Escribe un título para la alarma.';
    if (v.length > maxTitleLength) {
      return 'El título puede tener como máximo $maxTitleLength caracteres.';
    }
    return null;
  }

  static String? alarmMessage(String? value) {
    if (value == null) return null;
    return value.trim().length > maxMessageLength
        ? 'El mensaje puede tener como máximo $maxMessageLength caracteres.'
        : null;
  }

  static String? groupName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Escribe un nombre para el grupo.';
    if (v.length > maxGroupNameLength) {
      return 'El nombre puede tener como máximo $maxGroupNameLength caracteres.';
    }
    return null;
  }

  static bool isUuid(String? value) => value != null && _uuid.hasMatch(value);
}
