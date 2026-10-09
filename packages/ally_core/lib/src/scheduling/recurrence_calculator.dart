import '../domain/enums.dart';
import '../domain/local_date_time.dart';
import '../domain/repeat_rule.dart';

/// Calcula ocurrencias de una alarma en hora de pared.
///
/// Trabajar en hora local (y no en UTC) garantiza que una alarma diaria a las
/// 08:00 siga sonando a las 08:00 tras un cambio de horario de verano.
class RecurrenceCalculator {
  const RecurrenceCalculator();

  /// Primera ocurrencia estrictamente posterior a [after] (o igual si
  /// [inclusive]). `null` si la alarma ya no tiene más ocurrencias.
  LocalDateTime? nextOccurrence({
    required LocalDateTime start,
    required RepeatRule? rule,
    required LocalDateTime after,
    bool inclusive = false,
  }) {
    bool accepts(LocalDateTime c) =>
        inclusive ? !c.isBefore(after) : c.isAfter(after);

    if (rule == null) return accepts(start) ? start : null;

    for (final candidate in _iterate(start, rule)) {
      if (rule.until != null && candidate.date.isAfter(rule.until!)) {
        return null;
      }
      if (accepts(candidate)) return candidate;
    }
    return null;
  }

  /// Ocurrencias en el intervalo `[from, to)`, como máximo [limit].
  List<LocalDateTime> occurrencesBetween({
    required LocalDateTime start,
    required RepeatRule? rule,
    required LocalDateTime from,
    required LocalDateTime to,
    int limit = 500,
  }) {
    final result = <LocalDateTime>[];
    var cursor = nextOccurrence(
      start: start,
      rule: rule,
      after: from,
      inclusive: true,
    );
    while (cursor != null && cursor.isBefore(to) && result.length < limit) {
      result.add(cursor);
      cursor = nextOccurrence(start: start, rule: rule, after: cursor);
    }
    return result;
  }

  /// Genera ocurrencias en orden desde [start] (acotado a ~50 años).
  Iterable<LocalDateTime> _iterate(LocalDateTime start, RepeatRule rule) sync* {
    final time = start.time;
    switch (rule.frequency) {
      case RepeatFrequency.daily:
        for (var k = 0; k < 366 * 50; k++) {
          yield start.date.addDays(k * rule.interval).at(time);
        }
      case RepeatFrequency.weekly:
        // Semana ancla: el lunes de la semana de inicio.
        final anchorMonday = start.date.addDays(1 - start.date.weekday);
        final days = rule.sortedDays;
        for (var week = 0; week < 53 * 50; week += rule.interval) {
          final monday = anchorMonday.addDays(week * 7);
          for (final d in days) {
            final candidate = monday.addDays(d - 1).at(time);
            if (!candidate.isBefore(start)) yield candidate;
          }
        }
      case RepeatFrequency.monthly:
        final targetDay = rule.dayOfMonth ?? start.date.day;
        for (var k = 0; k < 12 * 50; k += rule.interval) {
          final monthIndex = start.date.month - 1 + k;
          final year = start.date.year + monthIndex ~/ 12;
          final month = monthIndex % 12 + 1;
          final day = targetDay.clamp(1, LocalDate.daysInMonth(year, month));
          final candidate = LocalDate(year, month, day).at(time);
          if (!candidate.isBefore(start)) yield candidate;
        }
    }
  }
}
