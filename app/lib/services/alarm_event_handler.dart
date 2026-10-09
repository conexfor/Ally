import 'dart:async';

import 'package:alarm/alarm.dart' as native;
import 'package:flutter/foundation.dart';
import 'package:ally_core/ally_core.dart';

import '../app/app_services.dart';

/// Procesa lo que el sistema hizo con las alarmas mientras la app no estaba
/// abierta (el plugin lo guarda y lo entrega al iniciar):
///
/// - "Posponer" pulsado en la notificación → se registra la respuesta
///   (el creador lo ve y los otros dispositivos dejan de sonar).
/// - Alarma descartada por el sistema (reinicio, sin permiso) → se avisa.
/// - "Confirmar" pulsado en la notificación → se registra como confirmada.
///   El plugin no avisa de ese botón (solo detiene el sonido), así que se
///   deduce: una alarma que ya sonó, que el plugin ya no tiene (ni sonando ni
///   pospuesta) y sin respuesta, solo pudo pararse con ese botón.
///
/// El plugin se inicia con `acknowledgeEventsAutomatically: false`: cada
/// evento se confirma solo después de guardarlo, así no se pierde si la app
/// se cierra a mitad de camino.
class AlarmEventHandler {
  final AppServices services;
  StreamSubscription<native.AlarmEvent>? _subscription;
  StreamSubscription<Object?>? _ringingSubscription; // AlarmSet no es público
  final _handled = <(int, int)>{};
  var _ringingIds = <int>{};

  /// Margen para que llegue antes un posible evento de "Posponer".
  static const _settleDelay = Duration(seconds: 3);

  /// Más antigua que esto, no se supone nada (p. ej. el teléfono estuvo apagado).
  static const _maxAge = Duration(hours: 12);

  AlarmEventHandler(this.services);

  void start() {
    _subscription ??= native.Alarm.events.listen((event) => unawaited(_handle(event)));
    // Cuando una alarma deja de sonar con la app abierta.
    _ringingSubscription ??= native.Alarm.ringing.listen((set) {
      final ids = {for (final a in (set as dynamic).alarms as Iterable) (a as native.AlarmSettings).id};
      if (_ringingIds.difference(ids).isNotEmpty) Timer(_settleDelay, () => unawaited(reconcileConfirmed()));
      _ringingIds = ids;
    });
    // Las que se confirmaron con la app cerrada.
    Timer(_settleDelay, () => unawaited(reconcileConfirmed()));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _ringingSubscription?.cancel();
  }

  /// Registra como confirmadas las alarmas paradas desde el botón "Confirmar"
  /// de la notificación (ver la documentación de la clase).
  Future<void> reconcileConfirmed() async {
    try {
      final me = await services.store.me();
      if (me == null) return;
      final now = DateTime.now();
      final inPlugin = {for (final a in await native.Alarm.getAlarms()) a.id};
      final answered = {
        for (final r in await services.store.responsesFor(me.id))
          if (r.response == ResponseStatus.confirmed || r.response == ResponseStatus.dismissed)
            (r.alarmId, r.occurrenceAt.millisecondsSinceEpoch),
      };
      for (final s in await services.store.scheduledNative()) {
        final ringAt = DateTime.fromMillisecondsSinceEpoch(s.ringAtMs);
        if (ringAt.isAfter(now) || inPlugin.contains(s.nativeId)) continue; // Aún no suena, suena o se pospuso.
        if (answered.contains((s.alarmId, s.occurrenceMs)) || now.difference(ringAt) > _maxAge) {
          await services.store.removeScheduledNative(s.nativeId);
          continue;
        }
        final alarm = await services.store.alarm(s.alarmId);
        if (alarm != null) {
          await services.alarms.respond(
            alarm,
            DateTime.fromMillisecondsSinceEpoch(s.occurrenceMs, isUtc: true),
            ResponseStatus.confirmed,
          );
        }
        await services.store.removeScheduledNative(s.nativeId);
      }
    } catch (e) {
      // Sin conexión o sin sesión: la respuesta queda en cola o se reintenta al abrir.
      debugPrint('AlarmEventHandler.reconcileConfirmed: $e');
    }
  }

  Future<void> _handle(native.AlarmEvent event) async {
    final key = (event.id, event.recordedAt.millisecondsSinceEpoch);
    if (!_handled.add(key)) return;
    try {
      switch (event) {
        case native.AlarmMoved(cause: native.AlarmEventCause.snooze, :final nextRingAt):
          await _onSnoozed(event.id, event.recordedAt, nextRingAt);
        case native.AlarmDropped():
          await _onDropped(event.id);
        case native.AlarmMoved():
          break;
      }
      await native.Alarm.acknowledgeEvent(event);
    } catch (e) {
      // Sin sesión o sin datos: se reintentará en el próximo inicio.
      _handled.remove(key);
      debugPrint('AlarmEventHandler: $e');
    }
  }

  Future<void> _onSnoozed(int nativeId, DateTime recordedAt, DateTime nextRingAt) async {
    final scheduled = await services.store.scheduledNativeById(nativeId);
    if (scheduled == null) return;
    final alarm = await services.store.alarm(scheduled.alarmId);
    if (alarm == null) return;
    final minutes = nextRingAt.difference(recordedAt).inMinutes.clamp(1, 1440);
    await services.alarms.respond(
      alarm,
      DateTime.fromMillisecondsSinceEpoch(scheduled.occurrenceMs, isUtc: true),
      ResponseStatus.snoozed,
      snoozeMinutes: minutes,
    );
  }

  Future<void> _onDropped(int nativeId) async {
    final scheduled = await services.store.scheduledNativeById(nativeId);
    final alarm = scheduled == null ? null : await services.store.alarm(scheduled.alarmId);
    await services.notifications.show(
      id: 'dropped:$nativeId',
      title: 'Una alarma no pudo sonar',
      body: alarm == null
          ? 'El sistema no permitió que sonara una alarma. Revisa los permisos de alarmas.'
          : '«${alarm.title}» no sonó. Revisa los permisos de alarmas en Configuración.',
      route: alarm == null ? '/settings' : '/alarms/${alarm.id}',
    );
    if (scheduled != null) await services.store.removeScheduledNative(nativeId);
    await services.scheduler.reschedule();
  }
}
