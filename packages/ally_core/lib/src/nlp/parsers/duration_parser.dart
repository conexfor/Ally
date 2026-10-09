import '../lexicon/number_lexicon.dart';
import '../parse_state.dart';

/// Reconoce duraciones para posponer: "10 minutos", "media hora",
/// "una hora y media", "un cuarto de hora", "5 min más".
class DurationParser {
  static final _pattern = RegExp(
    '\\b(?:(?<onehalf>una\\s+hora\\s+y\\s+media)|(?<quarter>un\\s+cuarto\\s+de\\s+hora)|(?<half>media\\s+hora)|(?<n>$numberPattern)\\s*(?<u>minutos?|min|m|horas?|h)(?![a-z]))(?:\\s+mas)?',
  );

  /// Duración en minutos o `null` si no se menciona.
  int? parse(ParseState state) {
    final match = _pattern.firstMatch(state.available);
    if (match == null) return null;
    int? minutes;
    if (match.namedGroup('onehalf') != null) {
      minutes = 90;
    } else if (match.namedGroup('quarter') != null) {
      minutes = 15;
    } else if (match.namedGroup('half') != null) {
      minutes = 30;
    } else {
      final n = parseNumber(match.namedGroup('n')!);
      if (n == null) return null;
      minutes = match.namedGroup('u')!.startsWith('h') ? n * 60 : n;
    }
    state.consumeMatch(match);
    return minutes;
  }
}
