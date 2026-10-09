import 'package:meta/meta.dart';

import 'enums.dart';
import 'local_date_time.dart';

/// Nombres de días de la semana en el formato de la API (`monday`...).
const weekdayWireNames = {
  DateTime.monday: 'monday',
  DateTime.tuesday: 'tuesday',
  DateTime.wednesday: 'wednesday',
  DateTime.thursday: 'thursday',
  DateTime.friday: 'friday',
  DateTime.saturday: 'saturday',
  DateTime.sunday: 'sunday',
};

int weekdayFromWire(String name) => weekdayWireNames.entries
    .firstWhere(
      (e) => e.value == name,
      orElse: () => throw FormatException('Día inválido: $name'),
    )
    .key;

/// Regla de repetición de una alarma.
///
/// - `daily`: cada [interval] días.
/// - `weekly`: los [daysOfWeek] de cada [interval] semanas.
/// - `monthly`: el día [dayOfMonth] (o el de la fecha inicial) cada [interval]
///   meses; si el mes no tiene ese día se usa el último día del mes.
@immutable
class RepeatRule {
  final RepeatFrequency frequency;
  final int interval;
  final Set<int> daysOfWeek;
  final int? dayOfMonth;
  final LocalDate? until;

  RepeatRule({
    required this.frequency,
    this.interval = 1,
    Set<int> daysOfWeek = const {},
    this.dayOfMonth,
    this.until,
  }) : daysOfWeek = Set.unmodifiable(daysOfWeek) {
    if (interval < 1) throw ArgumentError.value(interval, 'interval');
    if (frequency == RepeatFrequency.weekly && this.daysOfWeek.isEmpty) {
      throw ArgumentError('Una regla semanal necesita al menos un día');
    }
    if (this.daysOfWeek.any((d) => d < 1 || d > 7)) {
      throw ArgumentError.value(daysOfWeek, 'daysOfWeek');
    }
    if (dayOfMonth != null && (dayOfMonth! < 1 || dayOfMonth! > 31)) {
      throw ArgumentError.value(dayOfMonth, 'dayOfMonth');
    }
  }

  factory RepeatRule.daily({int interval = 1}) =>
      RepeatRule(frequency: RepeatFrequency.daily, interval: interval);

  factory RepeatRule.weekly(Set<int> days, {int interval = 1}) => RepeatRule(
        frequency: RepeatFrequency.weekly,
        daysOfWeek: days,
        interval: interval,
      );

  static final weekdaysOnly = RepeatRule.weekly({1, 2, 3, 4, 5});
  static final weekendsOnly = RepeatRule.weekly({6, 7});

  List<int> get sortedDays => daysOfWeek.toList()..sort();

  factory RepeatRule.fromJson(Map<String, dynamic> json) => RepeatRule(
        frequency: RepeatFrequency.fromWire(json['frequency'] as String),
        interval: (json['interval'] as num?)?.toInt() ?? 1,
        daysOfWeek: ((json['days'] as List?) ?? const [])
            .map((d) => weekdayFromWire(d as String))
            .toSet(),
        dayOfMonth: (json['day_of_month'] as num?)?.toInt(),
        until: json['until'] == null
            ? null
            : LocalDate.parse(json['until'] as String),
      );

  Map<String, dynamic> toJson() => {
        'repeat': true,
        'frequency': frequency.wire,
        'interval': interval,
        'days': [for (final d in sortedDays) weekdayWireNames[d]],
        if (dayOfMonth != null) 'day_of_month': dayOfMonth,
        if (until != null) 'until': until.toString(),
      };

  @override
  bool operator ==(Object other) =>
      other is RepeatRule &&
      other.frequency == frequency &&
      other.interval == interval &&
      other.dayOfMonth == dayOfMonth &&
      other.until == until &&
      other.daysOfWeek.length == daysOfWeek.length &&
      other.daysOfWeek.containsAll(daysOfWeek);

  @override
  int get hashCode => Object.hash(
        frequency,
        interval,
        dayOfMonth,
        until,
        Object.hashAllUnordered(daysOfWeek),
      );

  @override
  String toString() => 'RepeatRule(${toJson()})';
}
