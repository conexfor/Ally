import 'package:meta/meta.dart';

/// Fecha de calendario sin hora ni zona horaria.
///
/// Las alarmas se definen en "hora de pared" del usuario (p. ej. 08:00 en
/// America/Bogota); la conversión a UTC se hace en los bordes del sistema.
@immutable
class LocalDate implements Comparable<LocalDate> {
  final int year;
  final int month;
  final int day;

  LocalDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month');
    }
    if (day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError.value(day, 'day');
    }
  }

  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate(dt.year, dt.month, dt.day);

  /// Parsea `yyyy-MM-dd`.
  factory LocalDate.parse(String iso) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (match == null) throw FormatException('Fecha inválida', iso);
    return LocalDate(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  static bool isValid(int year, int month, int day) =>
      month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth(year, month);

  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      return leap ? 29 : 28;
    }
    const days = [31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  /// 1 = lunes ... 7 = domingo (ISO 8601, igual que [DateTime.weekday]).
  int get weekday => _asUtc.weekday;

  DateTime get _asUtc => DateTime.utc(year, month, day);

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(_asUtc.add(Duration(days: days)));

  int daysUntil(LocalDate other) =>
      other._asUtc.difference(_asUtc).inDays;

  /// Próxima fecha (incluida esta si [includeToday]) cuyo día de semana es [weekday].
  LocalDate nextWeekday(int weekday, {bool includeToday = true}) {
    var delta = (weekday - this.weekday) % 7;
    if (delta == 0 && !includeToday) delta = 7;
    return addDays(delta);
  }

  LocalDateTime at(LocalTime time) => LocalDateTime(this, time);

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `yyyy-MM-dd`
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';

  String toJson() => toString();
}

/// Hora del día (minuto de precisión) sin zona horaria.
@immutable
class LocalTime implements Comparable<LocalTime> {
  final int hour;
  final int minute;

  LocalTime(this.hour, this.minute) {
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour, 'hour');
    if (minute < 0 || minute > 59) throw ArgumentError.value(minute, 'minute');
  }

  static bool isValid(int hour, int minute) =>
      hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;

  /// Parsea `HH:mm`.
  factory LocalTime.parse(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Hora inválida', value);
    return LocalTime(int.parse(match[1]!), int.parse(match[2]!));
  }

  factory LocalTime.fromDateTime(DateTime dt) => LocalTime(dt.hour, dt.minute);

  int get minutesOfDay => hour * 60 + minute;

  bool get isAm => hour < 12;

  /// Hora en formato 12h, p. ej. `8:00 AM`.
  String format12h() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${_two(minute)} ${isAm ? 'AM' : 'PM'}';
  }

  @override
  int compareTo(LocalTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  bool isBefore(LocalTime other) => compareTo(other) < 0;
  bool isAfter(LocalTime other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is LocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  /// `HH:mm`
  @override
  String toString() => '${_two(hour)}:${_two(minute)}';

  String toJson() => toString();
}

/// Fecha y hora de pared (sin zona horaria).
@immutable
class LocalDateTime implements Comparable<LocalDateTime> {
  final LocalDate date;
  final LocalTime time;

  const LocalDateTime(this.date, this.time);

  factory LocalDateTime.fromDateTime(DateTime dt) =>
      LocalDateTime(LocalDate.fromDateTime(dt), LocalTime.fromDateTime(dt));

  /// Parsea `yyyy-MM-ddTHH:mm`.
  factory LocalDateTime.parse(String value) {
    final parts = value.split('T');
    if (parts.length != 2) throw FormatException('Fecha/hora inválida', value);
    return LocalDateTime(
      LocalDate.parse(parts[0]),
      LocalTime.parse(parts[1].substring(0, 5)),
    );
  }

  /// Representación como [DateTime] "naive" (UTC usado solo como contenedor).
  DateTime toNaiveUtc() =>
      DateTime.utc(date.year, date.month, date.day, time.hour, time.minute);

  LocalDateTime addMinutes(int minutes) => LocalDateTime.fromDateTime(
        toNaiveUtc().add(Duration(minutes: minutes)),
      );

  bool isBefore(LocalDateTime other) => compareTo(other) < 0;
  bool isAfter(LocalDateTime other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDateTime other) {
    final byDate = date.compareTo(other.date);
    return byDate != 0 ? byDate : time.compareTo(other.time);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDateTime && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(date, time);

  @override
  String toString() => '${date}T$time';

  String toJson() => toString();
}

String _two(int n) => n.toString().padLeft(2, '0');
