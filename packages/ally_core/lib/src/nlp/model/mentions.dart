import '../../domain/enums.dart';
import '../lexicon/time_lexicon.dart';
import '../parse_state.dart';

/// Papel de una fecha u hora dentro de la frase.
///
/// En "Cambia la alarma de las 8 a las 9", "de las 8" es una [reference] a una
/// alarma existente y "a las 9" es el nuevo [value].
enum EntityRole { value, reference }

/// Hora tal como la escribió el usuario, aún sin resolver AM/PM.
class TimeMention {
  /// Hora escrita (0–23).
  final int hour;
  final int minute;

  /// `am`, `pm` o `null` si no se indicó.
  final String? meridiem;
  final DayPeriod? period;

  /// Formato inequívoco de 24 h: hora > 12, hora 0 o con cero inicial (08:00).
  final bool is24h;

  /// "mediodía" o "medianoche".
  final bool isNamed;
  final EntityRole role;
  final TextSpan span;

  const TimeMention({
    required this.hour,
    required this.minute,
    required this.span,
    this.meridiem,
    this.period,
    this.is24h = false,
    this.isNamed = false,
    this.role = EntityRole.value,
  });

  /// La hora no admite otra interpretación.
  bool get isUnambiguous =>
      is24h || isNamed || meridiem != null || period != null;

  @override
  String toString() =>
      'TimeMention($hour:$minute, meridiem: $meridiem, period: $period, '
      '24h: $is24h, role: $role)';
}

/// "en 10 minutos", "dentro de una hora".
class RelativeTimeMention {
  final int minutes;
  final TextSpan span;
  const RelativeTimeMention(this.minutes, this.span);
}

enum DateMentionKind { relativeDays, weekday, explicit }

/// Fecha tal como la escribió el usuario.
class DateMention {
  final DateMentionKind kind;

  /// Para [DateMentionKind.relativeDays]: 0 = hoy, 1 = mañana...
  final int? relativeDays;

  /// Para [DateMentionKind.weekday]: 1 = lunes ... 7 = domingo.
  final int? weekday;

  /// "el próximo lunes": siempre posterior a hoy.
  final bool strictlyNext;

  /// "este lunes": puede ser hoy.
  final bool thisWeek;

  final int? year;
  final int? month;
  final int? day;

  /// Franja asociada ("esta noche" → hoy + noche).
  final DayPeriod? period;
  final EntityRole role;
  final TextSpan span;

  const DateMention({
    required this.kind,
    required this.span,
    this.relativeDays,
    this.weekday,
    this.strictlyNext = false,
    this.thisWeek = false,
    this.year,
    this.month,
    this.day,
    this.period,
    this.role = EntityRole.value,
  });

  @override
  String toString() =>
      'DateMention($kind, rel: $relativeDays, weekday: $weekday, '
      '$year-$month-$day, role: $role)';
}

/// Recurrencia reconocida.
class RecurrenceMention {
  final RepeatFrequency frequency;
  final int interval;
  final Set<int> daysOfWeek;
  final int? dayOfMonth;

  /// "todas las mañanas" → franja que ayuda a resolver AM/PM.
  final DayPeriod? period;

  const RecurrenceMention({
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek = const {},
    this.dayOfMonth,
    this.period,
  });

  @override
  String toString() =>
      'RecurrenceMention($frequency, every $interval, days: $daysOfWeek)';
}

enum RecipientMentionKind {
  /// Nombre de persona ("Juan", "Carlos Pérez").
  person,

  /// `@usuario`.
  username,

  /// Grupo explícito ("el grupo Familia", "todo el equipo").
  group,
}

/// Destinatario mencionado, aún sin resolver contra los contactos.
class RecipientMention {
  /// Texto original (con mayúsculas y acentos), sin artículos.
  final String raw;

  /// Clave normalizada para comparar con nombres.
  final String key;
  final RecipientMentionKind kind;

  /// Venía precedido de artículo ("la reunión"): si no coincide con ningún
  /// contacto probablemente no es una persona.
  final bool hadArticle;

  /// Parece un verbo en infinitivo ("para despertar"): si no coincide con
  /// ningún contacto se interpreta como el motivo de la alarma.
  final bool looksLikeInfinitive;

  const RecipientMention({
    required this.raw,
    required this.key,
    required this.kind,
    this.hadArticle = false,
    this.looksLikeInfinitive = false,
  });

  @override
  String toString() => 'RecipientMention($kind: $raw)';
}

/// Fragmento "para Juan, Pedro y María" con sus destinatarios.
class RecipientSegment {
  /// Texto original completo del segmento (sin la preposición).
  final String originalText;
  final List<RecipientMention> items;

  /// Introducido por "con" ("alarma a las 4 con Ana"): si nada coincide con
  /// un contacto no se trata como destinatario ("con sonido suave").
  final bool tentative;

  const RecipientSegment(this.originalText, this.items, {this.tentative = false});
}
