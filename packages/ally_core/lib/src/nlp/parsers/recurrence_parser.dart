import '../../domain/enums.dart';
import '../lexicon/date_lexicon.dart';
import '../lexicon/number_lexicon.dart';
import '../lexicon/recurrence_lexicon.dart';
import '../lexicon/time_lexicon.dart';
import '../model/mentions.dart';
import '../parse_state.dart';

/// Reconoce recurrencias: "todos los días", "cada lunes y miércoles",
/// "de lunes a viernes", "los fines de semana", "cada 2 días"...
///
/// Se ejecuta antes que el parser de fechas para que "todos los lunes" no se
/// interprete como la fecha "lunes".
class RecurrenceParser {
  static final _weekday = alternation(weekdayWords.keys);
  static final _period = alternation(
    dayPeriodWords.keys.where((k) => k != 'mediodia'),
  );

  static final _weekdaysPattern = RegExp('\\b(?:${alternation(weekdayPhrases)})\\b');
  static final _weekendPattern = RegExp('\\b(?:${alternation(weekendPhrases)})\\b');
  static final _rangePattern = RegExp(
    '\\b(?:todos\\s+los\\s+dias\\s+)?de\\s+($_weekday)\\s+a\\s+($_weekday)\\b',
  );
  static final _everyNDaysPattern = RegExp('\\bcada\\s+($numberPattern)\\s+dias\\b');
  static final _everyNWeeksPattern = RegExp('\\bcada\\s+($numberPattern)\\s+semanas\\b');
  static final _dailyPeriodPattern = RegExp(
    '\\b(?:${alternation(dailyPeriodPrefix)})\\s+($_period)\\b',
  );
  static final _dailyPattern = RegExp('\\b(?:${alternation(dailyPhrases)})\\b');
  static final _weekdayListPattern = RegExp(
    '\\b(?:${alternation(weeklyListPrefixes)})\\s+'
    '((?:$_weekday)(?:\\s*(?:,|\\by\\b|\\be\\b)\\s*(?:(?:los|el)\\s+)?(?:$_weekday))*)\\b',
  );
  static final _weeklyPattern = RegExp('\\b(?:${alternation(weeklyPhrases)})\\b');
  static final _monthlyDayPattern = RegExp(
    '\\b(?:el\\s+)?(?:dia\\s+)?($numberPattern)\\s+de\\s+cada\\s+mes\\b',
  );
  static final _monthlyPattern = RegExp('\\b(?:${alternation(monthlyPhrases)})\\b');

  RecurrenceMention? parse(ParseState state) {
    return _parseWeekdays(state) ??
        _parseWeekend(state) ??
        _parseRange(state) ??
        _parseEveryNDays(state) ??
        _parseDailyWithPeriod(state) ??
        _parseDaily(state) ??
        _parseWeekdayList(state) ??
        _parseWeekly(state) ??
        _parseMonthly(state);
  }

  RecurrenceMention? _parseWeekdays(ParseState state) =>
      _simple(state, _weekdaysPattern, {1, 2, 3, 4, 5});

  RecurrenceMention? _parseWeekend(ParseState state) =>
      _simple(state, _weekendPattern, {6, 7});

  RecurrenceMention? _simple(ParseState state, RegExp pattern, Set<int> days) {
    final match = pattern.firstMatch(state.available);
    if (match == null) return null;
    state.consumeMatch(match);
    return RecurrenceMention(
      frequency: RepeatFrequency.weekly,
      daysOfWeek: days,
    );
  }

  RecurrenceMention? _parseRange(ParseState state) {
    final match = _rangePattern.firstMatch(state.available);
    if (match == null) return null;
    final from = weekdayWords[match[1]]!;
    final to = weekdayWords[match[2]]!;
    final days = <int>{};
    for (var d = from;; d = d % 7 + 1) {
      days.add(d);
      if (d == to) break;
    }
    state.consumeMatch(match);
    return RecurrenceMention(frequency: RepeatFrequency.weekly, daysOfWeek: days);
  }

  RecurrenceMention? _parseEveryNDays(ParseState state) {
    final match = _everyNDaysPattern.firstMatch(state.available);
    if (match == null) return null;
    final n = parseNumber(match[1]!);
    if (n == null || n < 1) return null;
    state.consumeMatch(match);
    return RecurrenceMention(frequency: RepeatFrequency.daily, interval: n);
  }

  RecurrenceMention? _parseDailyWithPeriod(ParseState state) {
    final match = _dailyPeriodPattern.firstMatch(state.available);
    if (match == null) return null;
    state.consumeMatch(match);
    return RecurrenceMention(
      frequency: RepeatFrequency.daily,
      period: dayPeriodWords[match[1]],
    );
  }

  RecurrenceMention? _parseDaily(ParseState state) {
    final match = _dailyPattern.firstMatch(state.available);
    if (match == null) return null;
    state.consumeMatch(match);
    return const RecurrenceMention(frequency: RepeatFrequency.daily);
  }

  RecurrenceMention? _parseWeekdayList(ParseState state) {
    final match = _weekdayListPattern.firstMatch(state.available);
    if (match == null) return null;
    final days = RegExp(_weekday)
        .allMatches(match[1]!)
        .map((m) => weekdayWords[m[0]]!)
        .toSet();
    state.consumeMatch(match);
    return RecurrenceMention(
      frequency: RepeatFrequency.weekly,
      daysOfWeek: days,
      interval: _consumeWeekInterval(state) ?? 1,
    );
  }

  /// "cada semana" / "cada 2 semanas": los días se toman de la fecha
  /// mencionada (o de hoy) al resolver.
  RecurrenceMention? _parseWeekly(ParseState state) {
    final interval = _consumeWeekInterval(state);
    if (interval != null) {
      return RecurrenceMention(frequency: RepeatFrequency.weekly, interval: interval);
    }
    final match = _weeklyPattern.firstMatch(state.available);
    if (match == null) return null;
    state.consumeMatch(match);
    return const RecurrenceMention(frequency: RepeatFrequency.weekly);
  }

  int? _consumeWeekInterval(ParseState state) {
    final match = _everyNWeeksPattern.firstMatch(state.available);
    if (match == null) return null;
    final n = parseNumber(match[1]!);
    if (n == null || n < 1) return null;
    state.consumeMatch(match);
    return n;
  }

  RecurrenceMention? _parseMonthly(ParseState state) {
    final dayMatch = _monthlyDayPattern.firstMatch(state.available);
    if (dayMatch != null) {
      final day = parseNumber(dayMatch[1]!);
      if (day != null && day >= 1 && day <= 31) {
        state.consumeMatch(dayMatch);
        return RecurrenceMention(
          frequency: RepeatFrequency.monthly,
          dayOfMonth: day,
        );
      }
    }
    final match = _monthlyPattern.firstMatch(state.available);
    if (match == null) return null;
    state.consumeMatch(match);
    return const RecurrenceMention(frequency: RepeatFrequency.monthly);
  }
}
