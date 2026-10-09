import '../../domain/enums.dart';
import '../../domain/local_date_time.dart';
import '../../domain/repeat_rule.dart';
import '../lexicon/time_lexicon.dart';
import '../model/command_draft.dart';
import '../model/interpretation_context.dart';
import '../model/mentions.dart';
import '../model/parsed_command.dart';

/// Interpretaciones posibles de una hora escrita.
class HourCandidates {
  /// Ordenadas: la interpretación habitual primero.
  final List<LocalTime> times;

  /// Hay dos lecturas y la tabla de usos habituales no decide.
  final bool trulyAmbiguous;

  const HourCandidates(this.times, {this.trulyAmbiguous = false});

  bool get isSingle => times.length == 1;
}

class ScheduleResolution {
  final LocalDate? date;
  final LocalTime? time;
  final bool dateInferred;
  final List<LocalDateTime> timeOptions;
  final RepeatRule? repeat;
  final DayPeriod? period;
  final bool invalidDate;

  const ScheduleResolution({
    this.date,
    this.time,
    this.dateInferred = false,
    this.timeOptions = const [],
    this.repeat,
    this.period,
    this.invalidDate = false,
  });
}

/// Resuelve fechas y horas mencionadas a valores concretos del calendario,
/// usando el contexto (hora actual) para decidir AM/PM cuando sea seguro.
///
/// Política de ambigüedad (ver `habitualMeridiem`):
/// 1. AM/PM explícito, franja ("de la tarde") o formato 24 h → sin dudas.
/// 2. Fecha futura explícita ("mañana a las 8") → uso habitual (08:00).
/// 3. Hoy o sin fecha → si la lectura habitual aún no pasó, se usa; si solo
///    una lectura queda en el futuro y el usuario dijo "hoy", se usa esa.
/// 4. En cualquier otro caso se pregunta ("¿8:00 AM o 8:00 PM?").
class ScheduleResolver {
  const ScheduleResolver();

  static HourCandidates hourCandidates(TimeMention mention, DayPeriod? period) {
    final h = mention.hour;
    final m = mention.minute;
    if (mention.isNamed || mention.is24h) {
      return HourCandidates([LocalTime(h, m)]);
    }
    if (mention.meridiem != null) {
      final hour = mention.meridiem == 'am' ? h % 12 : h % 12 + 12;
      return HourCandidates([LocalTime(hour, m)]);
    }
    final effectivePeriod = mention.period ?? period;
    if (effectivePeriod != null) {
      return HourCandidates([LocalTime(_applyPeriod(h, effectivePeriod), m)]);
    }
    final am = LocalTime(h % 12, m);
    final pm = LocalTime(h % 12 + 12, m);
    final habitual = habitualMeridiem[h];
    return switch (habitual) {
      'pm' => HourCandidates([pm, am]),
      'am' => HourCandidates([am, pm]),
      _ => HourCandidates([am, pm], trulyAmbiguous: true),
    };
  }

  /// Minutos dentro de los cuales una lectura AM/PM se considera inminente.
  static const _imminentMinutes = 90;

  /// La única lectura que ocurre en los próximos [_imminentMinutes] minutos
  /// (hoy o, si [allowTomorrow], pasada la medianoche), o `null` si no hay
  /// exactamente una.
  static LocalDateTime? _soonest(
    List<LocalTime> times,
    LocalDate today,
    LocalDateTime now,
    {required bool allowTomorrow}
  ) {
    final limit = now.addMinutes(_imminentMinutes);
    final soon = <LocalDateTime>[];
    for (final t in times) {
      var at = today.at(t);
      if (!at.isAfter(now) && allowTomorrow) at = today.addDays(1).at(t);
      if (at.isAfter(now) && !at.isAfter(limit)) soon.add(at);
    }
    return soon.length == 1 ? soon.single : null;
  }

  static int _applyPeriod(int h, DayPeriod period) => switch (period) {
        DayPeriod.morning => h == 12 ? 12 : h,
        DayPeriod.earlyMorning => h % 12,
        DayPeriod.afternoon => h < 12 ? h + 12 : h,
        DayPeriod.noon => h == 12 ? 12 : (h <= 4 ? h + 12 : h),
        DayPeriod.night => h == 12 ? 0 : (h <= 4 ? h : (h < 12 ? h + 12 : h)),
      };

  /// Fecha concreta para una mención, o `null` si no existe (31 de febrero).
  static LocalDate? resolveDate(DateMention mention, LocalDate today) {
    switch (mention.kind) {
      case DateMentionKind.relativeDays:
        return today.addDays(mention.relativeDays ?? 0);
      case DateMentionKind.weekday:
        return today.nextWeekday(mention.weekday!, includeToday: !mention.strictlyNext);
      case DateMentionKind.explicit:
        var year = mention.year ?? today.year;
        if (!LocalDate.isValid(year, mention.month!, mention.day!)) return null;
        var date = LocalDate(year, mention.month!, mention.day!);
        if (mention.year == null && date.isBefore(today)) {
          year += 1;
          if (!LocalDate.isValid(year, mention.month!, mention.day!)) return null;
          date = LocalDate(year, mention.month!, mention.day!);
        }
        return date;
    }
  }

  /// Fecha/hora de una alarma nueva.
  ScheduleResolution resolveForCreate(ParsedCommand parsed, InterpretationContext ctx) {
    final today = ctx.today;
    final now = ctx.nowLocal;

    final dateMention = _first(parsed.datesWithRole(EntityRole.value)) ??
        _first(parsed.dates);
    final timeMention = _first(parsed.timesWithRole(EntityRole.value)) ??
        _first(parsed.times);
    final period = timeMention?.period ??
        dateMention?.period ??
        parsed.standalonePeriod ??
        parsed.recurrence?.period;

    final explicitDate =
        dateMention == null ? null : resolveDate(dateMention, today);
    final invalidDate = dateMention != null && explicitDate == null;
    final repeat = _buildRepeat(parsed, explicitDate ?? today);

    // "en 10 minutos"
    if (parsed.relativeTime != null) {
      final at = now.addMinutes(parsed.relativeTime!.minutes);
      return ScheduleResolution(
        date: at.date,
        time: at.time,
        repeat: repeat,
        period: period,
      );
    }

    if (timeMention == null) {
      return ScheduleResolution(
        date: explicitDate,
        repeat: repeat,
        period: period,
        invalidDate: invalidDate,
      );
    }

    final candidates = hourCandidates(timeMention, period);
    LocalTime? time;
    var date = explicitDate;
    var options = <LocalDateTime>[];

    if (candidates.isSingle) {
      time = candidates.times.single;
    } else if (repeat != null ||
        (explicitDate != null && explicitDate != today)) {
      // Fecha futura o recurrencia: el uso habitual es suficiente.
      if (candidates.trulyAmbiguous) {
        options = [for (final t in candidates.times) (explicitDate ?? today).at(t)];
      } else {
        time = candidates.times.first;
      }
    } else {
      final future = candidates.times.where((t) => today.at(t).isAfter(now)).toList();
      final habitual = candidates.trulyAmbiguous ? null : candidates.times.first;
      // Una lectura que llega muy pronto es casi seguro la buscada, aunque no
      // sea la habitual: "a las 12:06" dicho a las 00:05 → 00:06 (no 12:06 del
      // mediodía); "a las 12:10" dicho a las 23:30 → 00:10 de mañana.
      final soon = _soonest(candidates.times, today, now, allowTomorrow: explicitDate == null);
      if (soon != null) {
        date = soon.date;
        time = soon.time;
      } else if (habitual != null && future.contains(habitual)) {
        time = habitual;
        date ??= today;
      } else if (explicitDate == today) {
        if (future.length == 1) {
          time = future.single;
        } else if (future.isEmpty) {
          time = habitual ?? candidates.times.first; // el validador avisará
        } else {
          options = [for (final t in future) today.at(t)];
        }
      } else if (future.isEmpty) {
        // Ambas lecturas ya pasaron hoy: mañana.
        date = today.addDays(1);
        if (habitual != null) {
          time = habitual;
        } else {
          options = [for (final t in candidates.times) date.at(t)];
        }
      } else if (future.length == 1) {
        // p. ej. "a las 8" a las 10:00 → ¿hoy 20:00 o mañana 08:00?
        final other = candidates.times.firstWhere((t) => t != future.single);
        options = [today.at(future.single), today.addDays(1).at(other)];
      } else {
        options = [for (final t in future) today.at(t)];
      }
    }

    return ScheduleResolution(
      date: options.isEmpty ? date : null,
      time: time,
      dateInferred: explicitDate == null,
      timeOptions: options,
      repeat: repeat,
      period: period,
      invalidDate: invalidDate,
    );
  }

  /// Referencia a una alarma existente ("la alarma de las 3 de mañana").
  ///
  /// Si [onlyReferences] es true (edición), solo se usan las menciones con
  /// rol de referencia ("de las 8"); las demás son los nuevos valores.
  AlarmTarget resolveTarget(
    ParsedCommand parsed,
    InterpretationContext ctx, {
    required bool onlyReferences,
  }) {
    final times = onlyReferences
        ? parsed.timesWithRole(EntityRole.reference)
        : parsed.times;
    final dates = onlyReferences
        ? parsed.datesWithRole(EntityRole.reference)
        : parsed.dates;
    final dateMention = _first(dates);
    final timeMention = _first(times);
    return AlarmTarget(
      date: dateMention == null ? null : resolveDate(dateMention, ctx.today),
      times: timeMention == null
          ? const []
          : hourCandidates(timeMention, parsed.standalonePeriod).times,
    );
  }

  /// Nuevos valores en una edición ("... a las 9", "... al viernes").
  ScheduleResolution resolveEditValues(
    ParsedCommand parsed,
    InterpretationContext ctx, {
    LocalTime? currentTime,
  }) {
    final dateMention = _first(parsed.datesWithRole(EntityRole.value));
    final timeMention = _first(parsed.timesWithRole(EntityRole.value));
    final date = dateMention == null ? null : resolveDate(dateMention, ctx.today);
    LocalTime? time;
    var options = <LocalDateTime>[];
    if (timeMention != null) {
      final candidates = hourCandidates(timeMention, parsed.standalonePeriod);
      if (candidates.isSingle) {
        time = candidates.times.single;
      } else if (currentTime != null) {
        // Se conserva la mitad del día de la alarma original.
        time = candidates.times.firstWhere(
          (t) => t.isAm == currentTime.isAm,
          orElse: () => candidates.times.first,
        );
      } else if (!candidates.trulyAmbiguous) {
        time = candidates.times.first;
      } else {
        options = [for (final t in candidates.times) (date ?? ctx.today).at(t)];
      }
    }
    return ScheduleResolution(
      date: date,
      time: time,
      timeOptions: options,
      repeat: parsed.recurrence == null ? null : _buildRepeat(parsed, date ?? ctx.today),
      invalidDate: dateMention != null && date == null,
    );
  }

  RepeatRule? _buildRepeat(ParsedCommand parsed, LocalDate baseDate) {
    final r = parsed.recurrence;
    if (r == null) return null;
    return switch (r.frequency) {
      RepeatFrequency.daily => RepeatRule.daily(interval: r.interval),
      RepeatFrequency.weekly => RepeatRule.weekly(
          r.daysOfWeek.isEmpty ? {baseDate.weekday} : r.daysOfWeek,
          interval: r.interval,
        ),
      RepeatFrequency.monthly => RepeatRule(
          frequency: RepeatFrequency.monthly,
          interval: r.interval,
          dayOfMonth: r.dayOfMonth ?? baseDate.day,
        ),
    };
  }

  static T? _first<T>(Iterable<T> items) => items.isEmpty ? null : items.first;
}
