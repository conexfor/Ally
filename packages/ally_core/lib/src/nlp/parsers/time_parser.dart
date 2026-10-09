import '../lexicon/number_lexicon.dart';
import '../lexicon/time_lexicon.dart';
import '../model/mentions.dart';
import '../parse_state.dart';

class TimeParseResult {
  final List<TimeMention> times;
  final RelativeTimeMention? relative;

  /// Franja mencionada sin hora concreta ("por la tarde").
  final DayPeriod? standalonePeriod;

  const TimeParseResult(this.times, this.relative, this.standalonePeriod);
}

/// Reconoce horas en sus distintas formas:
/// `8`, `8:00`, `08:00`, `8 am`, `8 p.m.`, `8 de la mañana`, `14:30`,
/// `2:30 pm`, `2 y media de la tarde`, `8 menos cuarto`, `mediodía`,
/// `en 10 minutos`...
///
/// No decide AM/PM cuando hay ambigüedad: eso lo hace `TimeResolver` con el
/// contexto (fecha, hora actual).
class TimeParser {
  static const _prefix = r'(?:\b(?:a|para)\s+)?(?:\b(?:las?)\s+)?';
  static final _h = numberPattern;
  static const _suffixWord = r'(?:\s*(?:horas|hora|hs|h)(?![a-z]))?';

  static String _meridiem(String name) =>
      '(?<$name>a\\.?\\s?m\\.?|p\\.?\\s?m\\.?)(?![a-z])';
  static String _period(String name) =>
      '(?:(?:de|en|por)\\s+la\\s+(?<$name>manana|tarde|noche|madrugada)|del?\\s+(?:el\\s+)?(?<${name}noon>mediodia))';
  static String _tail() =>
      '(?:\\s*${_meridiem('tm')})?(?:\\s+(?:en\\s+punto\\s+)?${_period('tp')})?';

  static final _relative = RegExp(
    '\\b(?:en|dentro\\s+de)\\s+(?:(?<onehalf>una\\s+hora\\s+y\\s+media)|(?<half>media\\s+hora)|(?<n>$numberPattern)\\s+(?<u>minutos?|horas?))\\b',
  );
  static final _clock = RegExp(
    '$_prefix\\b(?<h>\\d{1,2})\\s*[:.h]\\s*(?<m>\\d{2})(?!\\d)$_suffixWord${_tail()}',
  );
  static final _fraction = RegExp(
    '$_prefix\\b(?<h>$_h)\\s+(?<op>y|menos)\\s+(?<f>media|cuarto|$_h)(?:\\s+minutos)?\\b${_tail()}',
  );
  static final _withMeridiem = RegExp(
    '$_prefix\\b(?<h>$_h)\\s*${_meridiem('m')}',
  );
  static final _withPeriod = RegExp(
    '$_prefix\\b(?<h>$_h)(?:\\s+en\\s+punto)?\\s+${_period('p')}',
  );
  static final _withArticle = RegExp(
    '\\b(?:(?:a|para)\\s+)?\\b(?:las?)\\s+(?<h>$_h)(?:\\s*(?:horas|hora|hs|h)(?![a-z])|\\b)(?:\\s+en\\s+punto)?',
  );
  static final _named = RegExp(
    r'\b(?:(?:a|para)\s+)?(?:el\s+|la\s+)?(?<n>mediodia|medianoche)\b',
  );
  static final _standalonePeriod = RegExp(
    r'\b(?:por|en|de)\s+la\s+(?<p>manana|tarde|noche|madrugada)\b',
  );

  TimeParseResult parse(ParseState state) {
    final relative = _parseRelative(state);
    final times = <TimeMention>[
      ..._collect(state, _clock, _fromClock),
      ..._collect(state, _fraction, _fromFraction),
      ..._collect(state, _withMeridiem, _fromMeridiem),
      ..._collect(state, _withPeriod, _fromPeriod),
      ..._collect(state, _withArticle, _fromArticle),
      ..._collect(state, _named, _fromNamed),
    ]..sort((a, b) => a.span.start.compareTo(b.span.start));

    DayPeriod? standalone;
    final periodMatch = _standalonePeriod.firstMatch(state.available);
    if (periodMatch != null) {
      standalone = dayPeriodWords[periodMatch.namedGroup('p')];
      state.consumeMatch(periodMatch);
    }
    return TimeParseResult(times, relative, standalone);
  }

  RelativeTimeMention? _parseRelative(ParseState state) {
    final match = _relative.firstMatch(state.available);
    if (match == null) return null;
    int? minutes;
    if (match.namedGroup('onehalf') != null) {
      minutes = 90;
    } else if (match.namedGroup('half') != null) {
      minutes = 30;
    } else {
      final n = parseNumber(match.namedGroup('n')!);
      if (n == null) return null;
      minutes = match.namedGroup('u')!.startsWith('hora') ? n * 60 : n;
    }
    if (minutes <= 0) return null;
    state.consumeMatch(match);
    return RelativeTimeMention(minutes, TextSpan(match.start, match.end));
  }

  /// Aplica [pattern] repetidamente sobre el texto disponible.
  List<TimeMention> _collect(
    ParseState state,
    RegExp pattern,
    TimeMention? Function(RegExpMatch, EntityRole) build,
  ) {
    final found = <TimeMention>[];
    var searchFrom = 0;
    while (true) {
      final available = state.available;
      if (searchFrom >= available.length) break;
      final match = pattern.firstMatch(available.substring(searchFrom));
      if (match == null) break;
      final start = searchFrom + match.start;
      final end = searchFrom + match.end;
      final mention = build(match, _roleBefore(available, start));
      if (mention == null) {
        searchFrom = end;
        continue;
      }
      state.consume(start, end);
      found.add(mention.withSpan(TextSpan(start, end)));
      searchFrom = end;
    }
    return found;
  }

  /// "de las 8" se refiere a una alarma existente; "a las 9" es un valor.
  static EntityRole _roleBefore(String text, int start) {
    final before = text.substring(0, start);
    return RegExp(r'\b(?:de|del|desde)\s*$').hasMatch(before)
        ? EntityRole.reference
        : EntityRole.value;
  }

  TimeMention? _fromClock(RegExpMatch m, EntityRole role) {
    final rawHour = m.namedGroup('h')!;
    final hour = int.parse(rawHour);
    final minute = int.parse(m.namedGroup('m')!);
    if (hour > 23 || minute > 59) return null;
    return _build(
      hour: hour,
      minute: minute,
      leadingZero: rawHour.length == 2 && rawHour.startsWith('0'),
      meridiem: m.namedGroup('tm'),
      periodWord: m.namedGroup('tp') ?? m.namedGroup('tpnoon'),
      role: role,
    );
  }

  TimeMention? _fromFraction(RegExpMatch m, EntityRole role) {
    final rawHour = m.namedGroup('h')!;
    var hour = parseNumber(rawHour);
    final fractionRaw = m.namedGroup('f')!;
    final fraction = fractionWords[fractionRaw] ?? parseNumber(fractionRaw);
    if (hour == null || fraction == null || hour > 23 || fraction > 59) {
      return null;
    }
    // Una palabra suelta ("dos y media") solo cuenta con artículo o franja.
    final hasContext = m[0]!.contains(RegExp(r'^(?:a\s+|para\s+)?las?\s')) ||
        m.namedGroup('tm') != null ||
        m.namedGroup('tp') != null ||
        m.namedGroup('tpnoon') != null;
    if (int.tryParse(rawHour) == null && !hasContext) return null;

    var minute = fraction;
    if (m.namedGroup('op') == 'menos') {
      hour = hour == 1 ? 12 : (hour == 0 ? 23 : hour - 1);
      minute = 60 - fraction;
      if (minute == 60) minute = 0;
    }
    return _build(
      hour: hour,
      minute: minute,
      meridiem: m.namedGroup('tm'),
      periodWord: m.namedGroup('tp') ?? m.namedGroup('tpnoon'),
      role: role,
    );
  }

  TimeMention? _fromMeridiem(RegExpMatch m, EntityRole role) {
    final hour = parseNumber(m.namedGroup('h')!);
    if (hour == null || hour > 23) return null;
    return _build(hour: hour, minute: 0, meridiem: m.namedGroup('m'), role: role);
  }

  TimeMention? _fromPeriod(RegExpMatch m, EntityRole role) {
    final hour = parseNumber(m.namedGroup('h')!);
    if (hour == null || hour > 23) return null;
    return _build(
      hour: hour,
      minute: 0,
      periodWord: m.namedGroup('p') ?? m.namedGroup('pnoon'),
      role: role,
    );
  }

  TimeMention? _fromArticle(RegExpMatch m, EntityRole role) {
    final rawHour = m.namedGroup('h')!;
    final hour = parseNumber(rawHour);
    if (hour == null || hour > 23) return null;
    return _build(
      hour: hour,
      minute: 0,
      leadingZero: rawHour.length == 2 && rawHour.startsWith('0'),
      role: role,
    );
  }

  TimeMention? _fromNamed(RegExpMatch m, EntityRole role) {
    final noon = m.namedGroup('n') == 'mediodia';
    return TimeMention(
      hour: noon ? 12 : 0,
      minute: 0,
      isNamed: true,
      period: noon ? DayPeriod.noon : null,
      role: role,
      span: const TextSpan(0, 0),
    );
  }

  TimeMention? _build({
    required int hour,
    required int minute,
    required EntityRole role,
    bool leadingZero = false,
    String? meridiem,
    String? periodWord,
  }) {
    final normalizedMeridiem = meridiem == null
        ? null
        : (meridiem.startsWith('a') ? 'am' : 'pm');
    final is24h = hour > 12 || hour == 0 || leadingZero;
    return TimeMention(
      hour: hour,
      minute: minute,
      // "14 pm" es contradictorio: se ignora el indicador.
      meridiem: is24h && hour > 12 ? null : normalizedMeridiem,
      period: periodWord == null ? null : dayPeriodWords[periodWord],
      is24h: is24h,
      role: role,
      span: const TextSpan(0, 0),
    );
  }
}

extension on TimeMention {
  TimeMention withSpan(TextSpan span) => TimeMention(
        hour: hour,
        minute: minute,
        meridiem: meridiem,
        period: period,
        is24h: is24h,
        isNamed: isNamed,
        role: role,
        span: span,
      );
}
