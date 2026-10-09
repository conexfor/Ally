import '../model/command_draft.dart';
import '../model/command_intent.dart';
import '../model/interpretation_context.dart';

/// Busca, entre las alarmas del usuario, las que encajan con una referencia
/// como "la alarma de las 3" o "la de mañana".
class AlarmMatcher {
  const AlarmMatcher();

  List<AlarmCandidate> match(
    AlarmTarget target,
    CommandIntent intent,
    List<AlarmCandidate> alarms,
  ) {
    // Editar o eliminar requiere ser el creador; posponer o detener una
    // ocurrencia lo puede hacer cualquier destinatario.
    final pool = switch (intent) {
      CommandIntent.editAlarm || CommandIntent.deleteAlarm =>
        alarms.where((a) => a.isOwn),
      _ => alarms,
    }.toList();

    if (target.alarmId != null) {
      return pool.where((a) => a.alarmId == target.alarmId).toList();
    }

    if (target.date == null && target.times.isEmpty) {
      if (intent == CommandIntent.snoozeAlarm ||
          intent == CommandIntent.cancelAlarm) {
        final ringing = pool.where((a) => a.isRinging).toList();
        if (ringing.isNotEmpty) return ringing;
      }
      return _sorted(pool);
    }

    final matches = pool.where((alarm) {
      if (target.times.isNotEmpty && !target.times.contains(alarm.time)) {
        return false;
      }
      if (target.date != null && alarm.nextOccurrence?.date != target.date) {
        return false;
      }
      return true;
    }).toList();
    return _sorted(matches);
  }

  List<AlarmCandidate> _sorted(List<AlarmCandidate> alarms) => alarms
    ..sort((a, b) {
      final x = a.nextOccurrence;
      final y = b.nextOccurrence;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
}
