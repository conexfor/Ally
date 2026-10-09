import 'lexicon/filler_lexicon.dart';
import 'model/command_intent.dart';
import 'model/parsed_command.dart';
import 'parse_state.dart';
import 'parsers/date_parser.dart';
import 'parsers/duration_parser.dart';
import 'parsers/group_parser.dart';
import 'parsers/intent_detector.dart';
import 'parsers/message_parser.dart';
import 'parsers/recipient_parser.dart';
import 'parsers/recurrence_parser.dart';
import 'parsers/time_parser.dart';
import 'text_normalizer.dart';

/// Análisis sintáctico de un comando en lenguaje natural.
///
/// Flujo: normalización → mensaje → intent → recurrencia → horas → fechas →
/// destinatarios → palabras no reconocidas. Cada parser consume lo que
/// reconoce para que el siguiente no lo reinterprete.
///
/// No consulta contactos ni calendario: eso lo hace
/// `RuleBasedCommandInterpreter` en la fase de resolución.
class NaturalLanguageAlarmParser {
  final TextNormalizer _normalizer;
  final IntentDetector _intentDetector;
  final RecurrenceParser _recurrenceParser;
  final TimeParser _timeParser;
  final DateParser _dateParser;
  final DurationParser _durationParser;
  final RecipientParser _recipientParser;
  final GroupParser _groupParser;
  late final MessageParser _messageParser;

  NaturalLanguageAlarmParser({
    TextNormalizer normalizer = const TextNormalizer(),
    IntentDetector? intentDetector,
    RecurrenceParser? recurrenceParser,
    TimeParser? timeParser,
    DateParser? dateParser,
    DurationParser? durationParser,
    RecipientParser? recipientParser,
    GroupParser? groupParser,
  })  : _normalizer = normalizer,
        _intentDetector = intentDetector ?? IntentDetector(),
        _recurrenceParser = recurrenceParser ?? RecurrenceParser(),
        _timeParser = timeParser ?? TimeParser(),
        _dateParser = dateParser ?? DateParser(),
        _durationParser = durationParser ?? DurationParser(),
        _recipientParser = recipientParser ?? RecipientParser(),
        _groupParser = groupParser ?? GroupParser() {
    _messageParser = MessageParser(isSchedulingTail: _isSchedulingTail);
  }

  static const _groupIntents = {
    CommandIntent.createGroup,
    CommandIntent.addMember,
    CommandIntent.removeMember,
  };

  ParsedCommand parse(String text) {
    final normalized = _normalizer.normalize(text);
    final state = ParseState(normalized);

    // Los comandos de grupos no llevan mensaje ("grupo que se llame X").
    final preliminary = _intentDetector.detect(normalized.normalized);
    if (_groupIntents.contains(preliminary.intent)) {
      return _parseGroupCommand(state, preliminary.intent);
    }

    final message = _messageParser.extract(state);
    final detection = _intentDetector.detect(state.available);

    final duration = detection.intent == CommandIntent.snoozeAlarm
        ? _durationParser.parse(state)
        : null;
    final recurrence = _recurrenceParser.parse(state);
    final timeResult = _timeParser.parse(state);
    final dates = _dateParser.parse(state);
    final recipients = _recipientParser.parse(state);

    var intent = detection.intent;
    var explicit = detection.matched;
    final hasSchedule = timeResult.times.isNotEmpty ||
        timeResult.relative != null ||
        recurrence != null;
    if (!explicit && hasSchedule) {
      // "Todos los lunes a las 9 para el equipo": sin verbo, pero con hora.
      intent = CommandIntent.createAlarm;
      explicit = false;
    }

    return ParsedCommand(
      originalText: normalized.original,
      intent: intent,
      intentExplicit: explicit,
      times: timeResult.times,
      relativeTime: timeResult.relative,
      dates: dates,
      standalonePeriod: timeResult.standalonePeriod,
      recurrence: recurrence,
      recipientSegments: recipients.segments,
      includesSelf: recipients.includesSelf,
      message: message?.text,
      durationMinutes: duration,
      unrecognizedWords: _unrecognized(state),
    );
  }

  ParsedCommand _parseGroupCommand(ParseState state, CommandIntent intent) {
    final result = _groupParser.parse(state, intent);
    return ParsedCommand(
      originalText: state.original,
      intent: intent,
      groupName: result?.groupName,
      memberSegments: [if (result?.members != null) result!.members!],
      unrecognizedWords: _unrecognized(state),
    );
  }

  List<String> _unrecognized(ParseState state) =>
      state.remainingWords().where((w) => !isFillerWord(w)).toList();

  /// ¿El fragmento contiene solo fecha/hora/recurrencia y conectores?
  bool _isSchedulingTail(String normalizedTail) {
    final state = ParseState(NormalizedText(normalizedTail, normalizedTail));
    final recurrence = _recurrenceParser.parse(state);
    final time = _timeParser.parse(state);
    final dates = _dateParser.parse(state);
    final found = recurrence != null ||
        time.times.isNotEmpty ||
        time.relative != null ||
        dates.isNotEmpty;
    if (!found) return false;
    const connectors = {'a', 'el', 'la', 'las', 'los', 'de', 'y', 'e', 'en', 'por', 'para'};
    return state.remainingWords().every(connectors.contains);
  }
}
