import '../lexicon/date_lexicon.dart';
import '../lexicon/number_lexicon.dart';
import '../lexicon/time_lexicon.dart';
import '../model/mentions.dart';
import '../parse_state.dart';

/// Reconoce fechas: `hoy`, `mañana`, `pasado mañana`, días de la semana con
/// modificadores (`este lunes`, `el próximo lunes`, `el viernes`), fechas
/// explícitas (`3 de octubre`, `3/10`, `03/10/2026`, `2026-10-03`),
/// `esta noche`, `en 3 días`...
///
/// Debe ejecutarse después del [TimeParser], que consume "de la mañana" como
/// franja horaria antes de que pueda confundirse con la fecha "mañana".
class DateParser {
  static final _weekday = alternation(weekdayWords.keys);
  static final _month = alternation(monthWords.keys);
  static final _relativeDay = alternation(relativeDayWords.keys);
  static final _nextModifiers = alternation(nextWeekdayModifiers);
  static final _thisModifiers = alternation(thisWeekdayModifiers);
  static final _nextSuffixes = alternation(nextWeekdaySuffixes);

  static final _iso = RegExp(r'\b(?<y>\d{4})-(?<m>\d{1,2})-(?<d>\d{1,2})\b');
  static final _numeric = RegExp(
    r'\b(?<d>\d{1,2})[/-](?<m>\d{1,2})(?:[/-](?<y>\d{4}|\d{2}))?(?![\d:])',
  );
  static final _textual = RegExp(
    '(?:\\b(?:el\\s+)?(?:$_weekday)\\s+)?\\b(?:el\\s+)?(?:dia\\s+)?(?<d>$numberPattern)\\s+de\\s+(?<m>$_month)(?:\\s+(?:de|del)\\s+(?<y>\\d{4}))?\\b',
  );
  static final _thisPeriod = RegExp(r'\besta\s+(?<p>manana|tarde|noche|madrugada)\b');
  static final _relative = RegExp('\\b(?<r>$_relativeDay)\\b');
  static final _inDays = RegExp(
    '\\b(?:en|dentro\\s+de)\\s+(?<n>$numberPattern)\\s+dias\\b',
  );
  static final _weekdayExpr = RegExp(
    '\\b(?:(?<next>$_nextModifiers)\\s+|(?<this>$_thisModifiers)\\s+)?(?<w>$_weekday)(?:\\s+(?<suffix>$_nextSuffixes))?\\b',
  );

  List<DateMention> parse(ParseState state) {
    final found = <DateMention>[
      ..._collect(state, _iso, _fromNumbers),
      ..._collect(state, _textual, _fromTextual),
      ..._collect(state, _numeric, _fromNumbers),
      ..._collect(state, _thisPeriod, _fromThisPeriod),
      ..._collect(state, _inDays, _fromInDays),
      ..._collect(state, _relative, _fromRelative),
      ..._collect(state, _weekdayExpr, _fromWeekday),
    ]..sort((a, b) => a.span.start.compareTo(b.span.start));
    return found;
  }

  List<DateMention> _collect(
    ParseState state,
    RegExp pattern,
    DateMention? Function(RegExpMatch, EntityRole, TextSpan) build,
  ) {
    final found = <DateMention>[];
    var searchFrom = 0;
    while (true) {
      final available = state.available;
      if (searchFrom >= available.length) break;
      final match = pattern.firstMatch(available.substring(searchFrom));
      if (match == null) break;
      final span = TextSpan(searchFrom + match.start, searchFrom + match.end);
      final mention = build(match, _roleBefore(available, span.start), span);
      searchFrom = span.end;
      if (mention == null) continue;
      state.consume(span.start, span.end);
      found.add(mention);
    }
    return found;
  }

  /// "la alarma de mañana" → referencia; "al viernes", "para el lunes" → valor.
  static EntityRole _roleBefore(String text, int start) {
    final before = text.substring(0, start);
    return RegExp(r'\b(?:de|del|desde)\s*$').hasMatch(before)
        ? EntityRole.reference
        : EntityRole.value;
  }

  DateMention? _fromNumbers(RegExpMatch m, EntityRole role, TextSpan span) {
    final day = int.parse(m.namedGroup('d')!);
    final month = int.parse(m.namedGroup('m')!);
    var year = m.namedGroup('y') == null ? null : int.parse(m.namedGroup('y')!);
    if (year != null && year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateMention(
      kind: DateMentionKind.explicit,
      day: day,
      month: month,
      year: year,
      role: role,
      span: span,
    );
  }

  DateMention? _fromTextual(RegExpMatch m, EntityRole role, TextSpan span) {
    final day = parseNumber(m.namedGroup('d')!);
    final month = monthWords[m.namedGroup('m')];
    if (day == null || month == null || day < 1 || day > 31) return null;
    final year = m.namedGroup('y');
    return DateMention(
      kind: DateMentionKind.explicit,
      day: day,
      month: month,
      year: year == null ? null : int.parse(year),
      role: role,
      span: span,
    );
  }

  DateMention? _fromThisPeriod(RegExpMatch m, EntityRole role, TextSpan span) =>
      DateMention(
        kind: DateMentionKind.relativeDays,
        relativeDays: 0,
        period: dayPeriodWords[m.namedGroup('p')],
        role: role,
        span: span,
      );

  DateMention? _fromInDays(RegExpMatch m, EntityRole role, TextSpan span) {
    final n = parseNumber(m.namedGroup('n')!);
    if (n == null) return null;
    return DateMention(
      kind: DateMentionKind.relativeDays,
      relativeDays: n,
      role: role,
      span: span,
    );
  }

  DateMention? _fromRelative(RegExpMatch m, EntityRole role, TextSpan span) =>
      DateMention(
        kind: DateMentionKind.relativeDays,
        relativeDays: relativeDayWords[m.namedGroup('r')!.replaceAll(RegExp(r'\s+'), ' ')],
        role: role,
        span: span,
      );

  DateMention? _fromWeekday(RegExpMatch m, EntityRole role, TextSpan span) {
    final strictlyNext =
        m.namedGroup('next') != null || m.namedGroup('suffix') != null;
    final thisModifier = m.namedGroup('this');
    return DateMention(
      kind: DateMentionKind.weekday,
      weekday: weekdayWords[m.namedGroup('w')],
      strictlyNext: strictlyNext,
      thisWeek: thisModifier == 'este' || thisModifier == 'esta',
      role: role,
      span: span,
    );
  }
}
