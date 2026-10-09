import '../../scheduling/recurrence_calculator.dart';
import '../model/command_draft.dart';
import '../model/command_intent.dart';
import '../model/interpretation_context.dart';
import 'alarm_matcher.dart';

/// Completa los valores deducibles de un borrador. Se aplica tras construirlo
/// y tras cada respuesta del usuario:
///
/// - hora sin fecha → hoy si aún no pasó, si no mañana;
/// - recurrencia → la fecha es la primera ocurrencia futura;
/// - referencia a alarma con una sola coincidencia → se fija esa alarma.
class DraftNormalizer {
  final RecurrenceCalculator _calculator;
  final AlarmMatcher _matcher;

  const DraftNormalizer({
    RecurrenceCalculator calculator = const RecurrenceCalculator(),
    AlarmMatcher matcher = const AlarmMatcher(),
  })  : _calculator = calculator,
        _matcher = matcher;

  CommandDraft normalize(CommandDraft draft, InterpretationContext ctx) {
    var result = draft;
    if (draft.intent == CommandIntent.createAlarm && draft.time != null) {
      result = _resolveCreateDate(result, ctx);
    }
    if (draft.intent.targetsExistingAlarm &&
        draft.target != null &&
        draft.target!.alarmId == null) {
      final matches = _matcher.match(draft.target!, draft.intent, ctx.alarms);
      if (matches.length == 1) {
        result = result.copyWith(
          target: draft.target!.withAlarm(matches.single.alarmId, matches.single.title),
        );
      }
    }
    return result;
  }

  CommandDraft _resolveCreateDate(CommandDraft draft, InterpretationContext ctx) {
    final time = draft.time!;
    final now = ctx.nowLocal;
    if (draft.repeat != null) {
      final start = (draft.date ?? ctx.today).at(time);
      final first = _calculator.nextOccurrence(
        start: start.isBefore(now) ? ctx.today.at(time) : start,
        rule: draft.repeat,
        after: now,
      );
      return draft.copyWith(date: first?.date);
    }
    if (draft.date == null) {
      final today = ctx.today.at(time);
      return draft.copyWith(
        date: today.isAfter(now) ? ctx.today : ctx.today.addDays(1),
        dateInferred: true,
      );
    }
    return draft;
  }
}
