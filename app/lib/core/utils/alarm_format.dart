import 'package:ally_core/ally_core.dart';

/// Textos de presentación de alarmas (hora del dispositivo).
abstract final class AlarmFormat {
  static LocalDateTime toDeviceLocal(DateTime utc) => LocalDateTime.fromDateTime(utc.toLocal());

  static LocalDate get today => LocalDate.fromDateTime(DateTime.now());

  /// "08:00 AM"
  static String time(DateTime utc) => SpanishFormatter.time(toDeviceLocal(utc).time);

  /// "Mañana", "Lunes 5 de octubre"
  static String day(DateTime utc) => SpanishFormatter.date(toDeviceLocal(utc).date, today);

  static String next(Alarm alarm) {
    final next = alarm.nextOccurrenceAt;
    if (next == null) {
      return switch (alarm.status) {
        AlarmStatus.cancelled => 'Cancelada',
        _ => 'Sin próximas ocurrencias',
      };
    }
    return '${day(next)} · ${time(next)}';
  }

  static String? repeat(Alarm alarm) => alarm.repeat == null ? null : SpanishFormatter.repeat(alarm.repeat!);

  /// "Para ti", "Juan y María", "Equipo Desarrollo"...
  static String audience(Alarm alarm, String meId) {
    final groups = alarm.recipients.where((r) => r.recipientType == RecipientType.group).map((r) => r.displayName);
    final people = alarm.recipients
        .where((r) => r.recipientType == RecipientType.user && r.sourceGroupId == null && r.userId != meId)
        .map((r) => r.displayName);
    final includesMe = alarm.recipients.any((r) => r.userId == meId && r.sourceGroupId == null);
    final names = [...groups, ...people];
    if (alarm.creator.id != meId) return 'De ${alarm.creator.displayName}';
    if (names.isEmpty) return 'Para ti';
    return SpanishFormatter.joinList([if (includesMe) 'Tú', ...names]);
  }

  /// "3/4 confirmaron"
  static String? confirmations(Alarm alarm, String meId) {
    final people = alarm.recipients
        .where((r) => r.recipientType == RecipientType.user && r.permissionStatus == PermissionStatus.accepted)
        .toList();
    if (people.length < 2 && people.every((r) => r.userId == meId)) return null;
    final confirmed = people.where((r) => r.responseStatus == ResponseStatus.confirmed).length;
    return '$confirmed/${people.length} confirmaron';
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// "Faltan 2 h 15 min"
  static String countdown(DateTime utc, [DateTime? now]) {
    final diff = utc.difference(now ?? DateTime.now().toUtc());
    if (diff.isNegative) return 'Sonando ahora';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    if (d > 0) return 'Faltan $d d $h h';
    if (h > 0) return 'Faltan $h h $m min';
    if (m > 0) return 'Faltan $m min';
    return 'En menos de un minuto';
  }

  /// "Una vez", "Todos los días"...
  static String kind(Alarm alarm) => repeat(alarm) ?? 'Una vez';

  /// "Sábado, 3 de octubre"
  static String longDate(DateTime local) {
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre',
        'octubre', 'noviembre', 'diciembre'];
    final weekday = SpanishFormatter.weekdayName(local.weekday);
    return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${local.day} de ${months[local.month - 1]}';
  }

  /// Fecha corta: "5 oct 2026".
  static String shortDate(DateTime utc) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
    final l = utc.toLocal();
    return '${l.day} ${months[l.month - 1]} ${l.year}';
  }

  /// Personas que reciben la alarma (sin filas de grupo).
  static List<String> participants(Alarm alarm) => [
        for (final r in alarm.recipients)
          if (r.recipientType == RecipientType.user && r.permissionStatus != PermissionStatus.rejected) r.displayName,
      ];

  /// "hace 5 min", "hace 2 h", "hace 3 días".
  static String ago(DateTime utc, [DateTime? now]) {
    final diff = (now ?? DateTime.now().toUtc()).difference(utc);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return diff.inDays == 1 ? 'hace 1 día' : 'hace ${diff.inDays} días';
  }
}
