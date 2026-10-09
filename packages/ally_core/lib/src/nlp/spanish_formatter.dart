import '../domain/enums.dart';
import '../domain/local_date_time.dart';
import '../domain/repeat_rule.dart';
import 'lexicon/date_lexicon.dart';

/// Formatos en español para mensajes al usuario.
class SpanishFormatter {
  const SpanishFormatter._();

  /// "Nicolás, Juan y María"
  static String joinList(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
  }

  /// `08:00 AM`, `02:30 PM`
  static String time(LocalTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} '
        '${t.isAm ? 'AM' : 'PM'}';
  }

  /// `8:00 AM` (sin cero inicial, para preguntas).
  static String shortTime(LocalTime t) => t.format12h();

  /// "Hoy", "Mañana", "Pasado mañana", "Lunes 5 de octubre".
  static String date(LocalDate date, LocalDate today) {
    final diff = today.daysUntil(date);
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == 2) return 'Pasado mañana';
    final weekday = weekdayDisplayNames[date.weekday]!;
    final label =
        '${_capitalize(weekday)} ${date.day} de ${monthDisplayNames[date.month]}';
    return date.year == today.year ? label : '$label de ${date.year}';
  }

  static String weekdayName(int weekday) => weekdayDisplayNames[weekday]!;

  /// "Todos los días", "De lunes a viernes", "Todos los lunes y miércoles"...
  static String repeat(RepeatRule rule) {
    switch (rule.frequency) {
      case RepeatFrequency.daily:
        return rule.interval == 1 ? 'Todos los días' : 'Cada ${rule.interval} días';
      case RepeatFrequency.monthly:
        final every = rule.interval == 1 ? 'Cada mes' : 'Cada ${rule.interval} meses';
        return rule.dayOfMonth == null ? every : '$every, el día ${rule.dayOfMonth}';
      case RepeatFrequency.weekly:
        final days = rule.sortedDays;
        String label;
        if (days.length == 7) {
          label = 'Todos los días';
        } else if (_sameDays(days, [1, 2, 3, 4, 5])) {
          label = 'De lunes a viernes';
        } else if (_sameDays(days, [6, 7])) {
          label = 'Fines de semana';
        } else {
          final names = [for (final d in days) _plural(weekdayDisplayNames[d]!)];
          label = 'Todos los ${joinList(names)}';
        }
        return rule.interval == 1
            ? label
            : 'Cada ${rule.interval} semanas: ${label[0].toLowerCase()}${label.substring(1)}';
    }
  }

  /// "10 minutos", "1 hora", "1 h 30 min"
  static String duration(int minutes) {
    if (minutes < 60) return minutes == 1 ? '1 minuto' : '$minutes minutos';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return h == 1 ? '1 hora' : '$h horas';
    return '$h h $m min';
  }

  static bool _sameDays(List<int> a, List<int> b) =>
      a.length == b.length && a.every(b.contains);

  static String _plural(String day) =>
      day == 'sábado' || day == 'domingo' ? '${day}s' : day;

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
