import '../lexicon/time_lexicon.dart';
import 'command_intent.dart';
import 'mentions.dart';

/// Resultado sintáctico del análisis: qué se dijo, sin resolver todavía
/// contra el calendario ni contra los contactos del usuario.
class ParsedCommand {
  final String originalText;
  final CommandIntent intent;

  /// El intent se detectó por una palabra clave (y no por deducción).
  final bool intentExplicit;

  final List<TimeMention> times;
  final RelativeTimeMention? relativeTime;
  final List<DateMention> dates;

  /// Franja mencionada sin hora ("mañana por la tarde").
  final DayPeriod? standalonePeriod;
  final RecurrenceMention? recurrence;

  final List<RecipientSegment> recipientSegments;

  /// El usuario se incluyó a sí mismo ("recuérdame", "para mí").
  final bool includesSelf;

  final String? message;

  /// Duración en minutos ("posponer 10 minutos").
  final int? durationMinutes;

  /// Para comandos de grupos.
  final String? groupName;
  final List<RecipientSegment> memberSegments;

  /// Palabras que ningún parser reconoció.
  final List<String> unrecognizedWords;

  const ParsedCommand({
    required this.originalText,
    required this.intent,
    this.intentExplicit = true,
    this.times = const [],
    this.relativeTime,
    this.dates = const [],
    this.standalonePeriod,
    this.recurrence,
    this.recipientSegments = const [],
    this.includesSelf = false,
    this.message,
    this.durationMinutes,
    this.groupName,
    this.memberSegments = const [],
    this.unrecognizedWords = const [],
  });

  Iterable<TimeMention> timesWithRole(EntityRole role) =>
      times.where((t) => t.role == role);

  Iterable<DateMention> datesWithRole(EntityRole role) =>
      dates.where((d) => d.role == role);

  List<RecipientMention> get recipientMentions =>
      [for (final s in recipientSegments) ...s.items];

  @override
  String toString() => 'ParsedCommand(${intent.code}, times: $times, '
      'relative: ${relativeTime?.minutes}, period: $standalonePeriod, '
      'dates: $dates, recurrence: $recurrence, '
      'recipients: $recipientMentions, self: $includesSelf, '
      'message: $message, duration: $durationMinutes, group: $groupName, '
      'members: ${[for (final s in memberSegments) ...s.items]}, '
      'unrecognized: $unrecognizedWords)';
}
