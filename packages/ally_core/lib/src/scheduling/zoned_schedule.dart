import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/local_date_time.dart';
import '../domain/repeat_rule.dart';
import 'recurrence_calculator.dart';

/// Conversión entre hora de pared (por zona horaria IANA) y UTC.
///
/// Las alarmas se guardan con su hora local + zona horaria; las ocurrencias
/// se calculan en hora local (respetando cambios de horario) y se convierten
/// a UTC solo para programarlas o compararlas.
class ZonedSchedule {
  const ZonedSchedule._();

  static bool _initialized = false;

  /// Carga la base de datos de zonas horarias (idempotente).
  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  static bool isValidTimezone(String name) {
    ensureInitialized();
    try {
      tz.getLocation(name);
      return true;
    } on tz.LocationNotFoundException {
      return false;
    }
  }

  static tz.Location _location(String name) {
    ensureInitialized();
    return tz.getLocation(name);
  }

  static DateTime toUtc(LocalDateTime local, String timezone) {
    final zoned = tz.TZDateTime(
      _location(timezone),
      local.date.year,
      local.date.month,
      local.date.day,
      local.time.hour,
      local.time.minute,
    );
    return DateTime.fromMillisecondsSinceEpoch(
      zoned.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  static LocalDateTime toLocal(DateTime instant, String timezone) {
    final zoned = tz.TZDateTime.from(instant.toUtc(), _location(timezone));
    return LocalDateTime(
      LocalDate(zoned.year, zoned.month, zoned.day),
      LocalTime(zoned.hour, zoned.minute),
    );
  }

  /// Próxima ocurrencia (en UTC) estrictamente posterior a [afterUtc].
  static DateTime? nextOccurrenceUtc({
    required LocalDateTime start,
    required RepeatRule? rule,
    required String timezone,
    required DateTime afterUtc,
    bool inclusive = false,
    RecurrenceCalculator calculator = const RecurrenceCalculator(),
  }) {
    final next = calculator.nextOccurrence(
      start: start,
      rule: rule,
      after: toLocal(afterUtc, timezone),
      inclusive: inclusive,
    );
    return next == null ? null : toUtc(next, timezone);
  }

  /// Ocurrencias (en UTC) dentro de `[fromUtc, untilUtc)`.
  static List<DateTime> occurrencesBetweenUtc({
    required LocalDateTime start,
    required RepeatRule? rule,
    required String timezone,
    required DateTime fromUtc,
    required DateTime untilUtc,
    int limit = 200,
    RecurrenceCalculator calculator = const RecurrenceCalculator(),
  }) {
    final local = calculator.occurrencesBetween(
      start: start,
      rule: rule,
      from: toLocal(fromUtc, timezone),
      to: toLocal(untilUtc, timezone).addMinutes(1),
      limit: limit,
    );
    return [
      for (final occurrence in local)
        if (toUtc(occurrence, timezone).isBefore(untilUtc))
          toUtc(occurrence, timezone),
    ];
  }
}
