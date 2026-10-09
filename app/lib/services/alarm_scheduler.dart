import 'dart:convert';

import 'package:alarm/alarm.dart' as native;
import 'package:flutter/foundation.dart';
import 'package:ally_core/ally_core.dart';

import '../data/local/local_store.dart';

/// Datos que viajan con cada alarma nativa para saber a qué ocurrencia
/// pertenece cuando suena.
class RingPayload {
  final String alarmId;
  final DateTime occurrenceAt;
  const RingPayload(this.alarmId, this.occurrenceAt);

  String encode() => jsonEncode({'alarm_id': alarmId, 'occurrence_at': occurrenceAt.toUtc().toIso8601String()});

  static RingPayload? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RingPayload(json['alarm_id'] as String, DateTime.parse(json['occurrence_at'] as String));
    } catch (_) {
      return null;
    }
  }
}

/// Programa en el sistema operativo las alarmas que deben sonar en este
/// dispositivo, para que suenen aunque no haya conexión o la app esté cerrada.
///
/// La planificación ([RingPlanner]) es pura; esta clase solo aplica la
/// diferencia entre lo planificado y lo que ya está programado.
class AlarmScheduler {
  final LocalStore store;
  final RingPlanner planner;

  AlarmScheduler(this.store, {this.planner = const RingPlanner()});

  static const sounds = {'default': 'Sonido del sistema', 'classic': 'Clásico', 'soft': 'Suave'};

  Future<void> reschedule() async {
    final me = await store.me();
    if (me == null) return;
    final device = await store.device();
    final planned = planner.plan(
      alarms: await store.alarms(),
      myResponses: await store.responsesFor(me.id),
      userId: me.id,
      deviceId: device?.id,
      deviceReceivesAlarms: device?.receivesAlarms ?? true,
      devicePreferences: await store.devicePreferences(),
      now: DateTime.now(),
    );
    final wanted = {for (final ring in planned) ring.nativeId: ring};
    final current = {for (final s in await store.scheduledNative()) s.nativeId: s};
    final snooze = Duration(minutes: (await store.settings()).defaultSnoozeMinutes);

    for (final entry in current.entries) {
      if (!wanted.containsKey(entry.key)) {
        await _safe(() => native.Alarm.stop(entry.key));
        await store.removeScheduledNative(entry.key);
      }
    }
    for (final ring in planned) {
      final existing = current[ring.nativeId];
      if (existing != null && existing.ringAtMs == ring.ringAt.millisecondsSinceEpoch) continue;
      final ok = await _safe(() => native.Alarm.set(alarmSettings: _settingsFor(ring, me.id, snooze)));
      if (ok == true) {
        await store.saveScheduledNative(ring.nativeId, ring.alarm.id, ring.occurrenceAt, ring.ringAt);
      }
    }
  }

  /// Detiene una alarma que está sonando.
  Future<void> stop(int nativeId) async {
    await _safe(() => native.Alarm.stop(nativeId));
    await store.removeScheduledNative(nativeId);
  }

  Future<void> stopAll() async {
    await _safe(native.Alarm.stopAll);
    for (final s in await store.scheduledNative()) {
      await store.removeScheduledNative(s.nativeId);
    }
  }

  native.AlarmSettings _settingsFor(PlannedRing ring, String meId, Duration snooze) {
    final alarm = ring.alarm;
    final fromSomeoneElse = alarm.creator.id != meId;
    final body = alarm.message?.isNotEmpty == true
        ? alarm.message!
        : (fromSomeoneElse ? 'De ${alarm.creator.displayName}' : 'Toca para responder');
    final volume = switch (alarm.priority) {
      AlarmPriority.urgent => native.VolumeSettings.fade(fadeDuration: Duration(seconds: 3), volume: 1),
      AlarmPriority.important => native.VolumeSettings.fade(fadeDuration: Duration(seconds: 6), volume: 0.9),
      AlarmPriority.normal => native.VolumeSettings.fade(fadeDuration: Duration(seconds: 12), volume: 0.75),
    };
    return native.AlarmSettings(
      id: ring.nativeId,
      dateTime: ring.ringAt.toLocal(),
      // null = sonido de alarma predeterminado del dispositivo.
      assetAudioPath: alarm.sound == 'default' || !sounds.containsKey(alarm.sound)
          ? null
          : 'assets/sounds/${alarm.sound}.wav',
      loopAudio: true,
      vibrate: alarm.vibration,
      volumeSettings: volume,
      // Nunca se fuerza el volumen ni se salta el modo No molestar del sistema.
      androidFullScreenIntent: true,
      warningNotificationOnKill: defaultTargetPlatform == TargetPlatform.iOS,
      payload: RingPayload(alarm.id, ring.occurrenceAt).encode(),
      // Posponer desde la notificación: el plugin lo registra aunque la app esté
      // cerrada y AlarmEventHandler lo envía al servidor al reabrirla.
      androidSnoozeDuration: snooze,
      notificationSettings: native.NotificationSettings(
        title: '⏰ ${alarm.title}',
        body: body,
        // "Confirmar" solo detiene el sonido (el plugin no lo notifica);
        // AlarmEventHandler.reconcileConfirmed lo registra como confirmada.
        stopButton: 'Confirmar',
        androidSnoozeButton: 'Posponer ${snooze.inMinutes} min',
        androidStopAlarmOnDismiss: false,
        icon: 'notification_icon',
      ),
    );
  }

  /// Una llamada al plugin que no responde (p. ej. en el motor sin interfaz
  /// del asistente por voz) no debe bloquear: se reintenta en la siguiente
  /// reprogramación.
  static Future<T?> _safe<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('AlarmScheduler: $e');
      return null;
    }
  }
}
