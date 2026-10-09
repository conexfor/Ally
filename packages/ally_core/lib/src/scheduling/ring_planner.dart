import '../api/alarm_dtos.dart';
import '../domain/enums.dart';
import 'zoned_schedule.dart';

/// Una vez que la alarma debe sonar en este dispositivo.
class PlannedRing {
  final Alarm alarm;

  /// Ocurrencia a la que pertenece (la que se confirma/pospone).
  final DateTime occurrenceAt;

  /// Momento real en que suena (difiere si se pospuso).
  final DateTime ringAt;

  const PlannedRing(this.alarm, this.occurrenceAt, this.ringAt);

  /// ID estable para el sistema operativo (no depende de [ringAt]).
  int get nativeId => nativeIdFor(alarm.id, occurrenceAt);

  static int nativeIdFor(String alarmId, DateTime occurrenceAt) {
    // FNV-1a de 32 bits, positivo y distinto de cero.
    var hash = 0x811c9dc5;
    for (final unit in '$alarmId|${occurrenceAt.toUtc().millisecondsSinceEpoch}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final id = hash & 0x7FFFFFFF;
    return id == 0 ? 1 : id;
  }
}

/// Decide qué alarmas deben sonar en ESTE dispositivo y cuándo.
///
/// - Solo alarmas aceptadas por el usuario y activas.
/// - Respeta la preferencia por dispositivo (o el valor por defecto del
///   dispositivo) y las alarmas dirigidas a dispositivos concretos.
/// - Omite ocurrencias ya confirmadas/descartadas y reprograma las pospuestas.
/// - Programa como máximo [horizon] hacia delante: la sincronización y la
///   apertura de la app vuelven a planificar.
class RingPlanner {
  final Duration horizon;
  final int maxPerAlarm;
  final int maxTotal;

  const RingPlanner({
    this.horizon = const Duration(days: 7),
    this.maxPerAlarm = 8,
    this.maxTotal = 200,
  });

  List<PlannedRing> plan({
    required List<Alarm> alarms,
    required List<AlarmResponse> myResponses,
    required String userId,
    required String? deviceId,
    required bool deviceReceivesAlarms,
    required Map<String, Map<String, bool>> devicePreferences,
    required DateTime now,
  }) {
    final nowUtc = now.toUtc();
    final until = nowUtc.add(horizon);
    final responses = {
      for (final r in myResponses) '${r.alarmId}|${r.occurrenceAt.toUtc().millisecondsSinceEpoch}': r,
    };
    final result = <PlannedRing>[];

    for (final alarm in alarms) {
      if (!alarm.isActive || alarm.triggerType != TriggerType.time) continue;
      if (!_ringsHere(alarm, userId, deviceId, deviceReceivesAlarms, devicePreferences)) continue;

      final next = alarm.nextOccurrenceAt;
      if (next == null && alarm.repeat == null) {
        // Sin ocurrencias futuras, pero puede quedar una pospuesta.
        _addSnoozed(result, alarm, responses, userId, nowUtc);
        continue;
      }
      final from = next == null || next.isBefore(nowUtc) ? nowUtc : next;
      final occurrences = ZonedSchedule.occurrencesBetweenUtc(
        start: alarm.start,
        rule: alarm.repeat,
        timezone: alarm.timezone,
        fromUtc: from,
        untilUtc: until,
        limit: maxPerAlarm,
      );
      for (final occurrence in occurrences) {
        final response = responses['${alarm.id}|${occurrence.millisecondsSinceEpoch}'];
        if (response == null || response.response == ResponseStatus.noResponse) {
          result.add(PlannedRing(alarm, occurrence, occurrence));
        }
      }
      _addSnoozed(result, alarm, responses, userId, nowUtc);
    }

    result.sort((a, b) => a.ringAt.compareTo(b.ringAt));
    final unique = <int, PlannedRing>{};
    for (final ring in result) {
      unique.putIfAbsent(ring.nativeId, () => ring);
    }
    return unique.values.take(maxTotal).toList();
  }

  void _addSnoozed(
    List<PlannedRing> result,
    Alarm alarm,
    Map<String, AlarmResponse> responses,
    String userId,
    DateTime nowUtc,
  ) {
    for (final r in responses.values) {
      if (r.alarmId != alarm.id || r.userId != userId) continue;
      if (r.response == ResponseStatus.snoozed &&
          r.snoozedUntil != null &&
          r.snoozedUntil!.isAfter(nowUtc)) {
        result.add(PlannedRing(alarm, r.occurrenceAt.toUtc(), r.snoozedUntil!.toUtc()));
      }
    }
  }

  bool _ringsHere(
    Alarm alarm,
    String userId,
    String? deviceId,
    bool deviceReceivesAlarms,
    Map<String, Map<String, bool>> devicePreferences,
  ) {
    final mine = alarm.recipients.where((r) => r.userId == userId);
    final userRow = mine.where((r) => r.recipientType == RecipientType.user).firstOrNull;
    final deviceRows = mine.where((r) => r.recipientType == RecipientType.device).toList();

    if (deviceRows.isNotEmpty && userRow == null) {
      // Dirigida a dispositivos concretos.
      return deviceId != null && deviceRows.any((r) => r.recipientId == deviceId);
    }
    if (userRow == null || userRow.permissionStatus != PermissionStatus.accepted) return false;
    if (deviceRows.any((r) => r.recipientId == deviceId)) return true;
    final preference = deviceId == null ? null : devicePreferences[alarm.id]?[deviceId];
    return preference ?? deviceReceivesAlarms;
  }
}
