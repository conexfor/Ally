import 'dart:async';

import 'package:ally_core/ally_core.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../services/alarm_scheduler.dart';
import '../local/local_store.dart';
import '../remote/ally_api.dart';

/// Resultado de guardar: [queued] indica que se guardó sin conexión y se
/// enviará al servidor al recuperarla.
class SaveOutcome<T> {
  final T value;
  final bool queued;
  const SaveOutcome(this.value, {this.queued = false});
}

/// Alarmas con estrategia "offline-first": se intenta el servidor y, si no hay
/// conexión, se aplica el cambio localmente y se encola.
class AlarmRepository {
  final AllyApi api;
  final LocalStore store;
  final AlarmScheduler scheduler;
  static const _uuid = Uuid();

  /// Espera máxima al servidor antes de guardar sin conexión. El asistente por
  /// voz la acorta para responder rápido; es seguro porque el servidor trata
  /// como la misma alarma un reenvío con el mismo id.
  Duration? serverTimeout;

  AlarmRepository(this.api, this.store, this.scheduler);

  Future<T> _remote<T>(Future<T> call) {
    final limit = serverTimeout;
    if (limit == null) return call;
    return call.timeout(limit, onTimeout: () => throw const AppException.network());
  }

  Stream<List<Alarm>> watchAll() => store.watchAlarms();
  Stream<Alarm?> watch(String id) => store.watchAlarm(id);
  Stream<List<AlarmResponse>> watchResponses(String id) => store.watchResponses(id);

  Future<SaveOutcome<Alarm>> create(AlarmInput draft) async {
    final input = AlarmInput.fromJson({...draft.toJson(), 'id': draft.id ?? _uuid.v4()});
    try {
      final alarm = await _remote(api.createAlarm(input));
      await store.upsertAlarm(alarm);
      await scheduler.reschedule();
      return SaveOutcome(alarm);
    } on AppException catch (e) {
      if (!e.isNetwork) rethrow;
      final local = await _optimistic(input, null);
      await store.upsertAlarm(local, pending: true);
      await store.enqueue(OutboxKind.createAlarm, local.id, input.toJson());
      await scheduler.reschedule();
      return SaveOutcome(local, queued: true);
    }
  }

  Future<SaveOutcome<Alarm>> update(Alarm current, AlarmInput changes) async {
    final input = AlarmInput.fromJson({...changes.toJson(), 'base_version': current.version});
    // Si hay operaciones pendientes, este cambio también debe ir a la cola
    // para respetar el orden.
    if (!await store.hasOutboxFor(current.id)) {
      try {
        final alarm = await _remote(api.updateAlarm(current.id, input));
        await store.upsertAlarm(alarm);
        await scheduler.reschedule();
        return SaveOutcome(alarm);
      } on AppException catch (e) {
        if (!e.isNetwork) rethrow;
      }
    }
    final local = await _optimistic(input, current);
    await store.upsertAlarm(local, pending: true);
    await store.enqueue(OutboxKind.updateAlarm, current.id, input.toJson());
    await scheduler.reschedule();
    return SaveOutcome(local, queued: true);
  }

  Future<SaveOutcome<void>> delete(Alarm alarm) async {
    var queued = false;
    if (await store.hasOutboxFor(alarm.id)) {
      await store.enqueue(OutboxKind.deleteAlarm, alarm.id, const {});
      queued = true;
    } else {
      try {
        await _remote(api.deleteAlarm(alarm.id));
      } on AppException catch (e) {
        if (!e.isNetwork) rethrow;
        await store.enqueue(OutboxKind.deleteAlarm, alarm.id, const {});
        queued = true;
      }
    }
    await store.removeAlarm(alarm.id);
    await scheduler.reschedule();
    return SaveOutcome(null, queued: queued);
  }

  Future<SaveOutcome<Alarm>> cancelNext(Alarm alarm) async {
    try {
      final updated = await _remote(api.cancelNextOccurrence(alarm.id));
      await store.upsertAlarm(updated);
      await scheduler.reschedule();
      return SaveOutcome(updated);
    } on AppException catch (e) {
      if (!e.isNetwork) rethrow;
      await store.enqueue(OutboxKind.cancelAlarm, alarm.id, const {});
      final next = alarm.nextOccurrenceAt == null
          ? null
          : ZonedSchedule.nextOccurrenceUtc(
              start: alarm.start,
              rule: alarm.repeat,
              timezone: alarm.timezone,
              afterUtc: alarm.nextOccurrenceAt!,
            );
      final local = _copy(alarm, nextOccurrenceAt: next, status: next == null ? AlarmStatus.cancelled : null);
      await store.upsertAlarm(local, pending: true);
      await scheduler.reschedule();
      return SaveOutcome(local, queued: true);
    }
  }

  /// Confirmar, posponer o descartar una ocurrencia. Siempre se aplica en
  /// local primero para que la alarma deje de sonar al instante.
  Future<SaveOutcome<void>> respond(
    Alarm alarm,
    DateTime occurrenceAt,
    ResponseStatus response, {
    int? snoozeMinutes,
  }) async {
    final me = await store.me();
    final device = await store.device();
    if (me == null) throw const AppException.unexpected();
    final now = DateTime.now().toUtc();
    await store.upsertResponse(
      AlarmResponse(
        id: 'local-${alarm.id}-${occurrenceAt.millisecondsSinceEpoch}-${me.id}',
        alarmId: alarm.id,
        userId: me.id,
        occurrenceAt: occurrenceAt.toUtc(),
        response: response,
        snoozedUntil: response == ResponseStatus.snoozed
            ? now.add(Duration(minutes: snoozeMinutes ?? (await store.settings()).defaultSnoozeMinutes))
            : null,
        respondedAt: now,
        deviceId: device?.id,
      ),
    );
    await scheduler.reschedule();

    final input = RespondInput(
      occurrenceAt: occurrenceAt,
      response: response,
      snoozeMinutes: snoozeMinutes,
      deviceId: device?.id,
    );
    try {
      final updated = await api.respond(alarm.id, input);
      if (!await store.hasOutboxFor(alarm.id)) await store.upsertAlarm(updated);
      return const SaveOutcome(null);
    } on AppException catch (e) {
      if (!e.isNetwork) rethrow;
      await store.enqueue(OutboxKind.respond, alarm.id, input.toJson());
      return const SaveOutcome(null, queued: true);
    }
  }

  Future<Alarm> accept(Alarm alarm) async {
    final updated = await api.acceptAlarm(alarm.id);
    await store.upsertAlarm(updated);
    await scheduler.reschedule();
    return updated;
  }

  Future<void> reject(Alarm alarm) async {
    await api.rejectAlarm(alarm.id);
    await store.removeAlarm(alarm.id);
    await scheduler.reschedule();
  }

  Future<List<AlarmResponse>> responses(String alarmId) => api.alarmResponses(alarmId);

  // ------------------------------------------------------------------ rutinas

  /// Rutinas propias (requiere conexión).
  Future<List<AlarmSequence>> sequences() => api.sequences();

  /// Crea la rutina en el servidor (todos los pasos o ninguno) y guarda sus
  /// alarmas localmente para que suenen aunque luego no haya conexión.
  Future<AlarmSequence> createSequence(SequenceInput input) async {
    final sequence = await api.createSequence(input);
    for (final step in sequence.steps) {
      await store.upsertAlarm(await api.getAlarm(step.alarmId));
    }
    await scheduler.reschedule();
    return sequence;
  }

  Future<void> deleteSequence(AlarmSequence sequence) async {
    await api.deleteSequence(sequence.id);
    for (final step in sequence.steps) {
      await store.removeAlarm(step.alarmId);
    }
    await scheduler.reschedule();
  }

  Future<void> setDeviceEnabled(Alarm alarm, String deviceId, bool enabled) async {
    await api.setAlarmDevice(alarm.id, deviceId, enabled);
    final prefs = {...await store.devicePreferences()};
    prefs[alarm.id] = {...?prefs[alarm.id], deviceId: enabled};
    await store.saveDevicePreferences(prefs);
    await scheduler.reschedule();
  }

  // ---------------------------------------------------------- vista optimista

  /// Construye la alarma tal como quedará, para mostrarla y programarla sin
  /// esperar al servidor.
  Future<Alarm> _optimistic(AlarmInput input, Alarm? current) async {
    final me = (await store.me())!;
    final contacts = {for (final c in await store.contacts()) c.user.id: c};
    final groups = {for (final g in await store.groups()) g.id: g};
    final now = DateTime.now().toUtc();
    final start = input.localDate.at(input.localTime);

    final recipients = <AlarmRecipient>[];
    for (final r in input.recipients) {
      final existing = current?.recipients.where((x) => x.recipientType == r.type && x.recipientId == r.id).firstOrNull;
      if (existing != null) {
        recipients.add(existing);
        continue;
      }
      final isMe = r.type == RecipientType.user && r.id == me.id;
      recipients.add(
        AlarmRecipient(
          id: 'local-${r.type.wire}-${r.id}',
          recipientType: r.type,
          recipientId: r.id,
          userId: r.type == RecipientType.group ? null : (r.type == RecipientType.user ? r.id : me.id),
          displayName: switch (r.type) {
            RecipientType.user => isMe ? me.displayName : contacts[r.id]?.user.displayName ?? '',
            RecipientType.group => groups[r.id]?.name ?? '',
            RecipientType.device => (await store.device())?.deviceName ?? '',
          },
          permissionStatus: isMe || r.type != RecipientType.user
              ? PermissionStatus.accepted
              : (contacts[r.id]?.grantedToMe.autoAccept ?? false)
              ? PermissionStatus.accepted
              : PermissionStatus.pending,
          responseStatus: ResponseStatus.noResponse,
        ),
      );
    }
    if (recipients.isEmpty) {
      recipients.add(
        AlarmRecipient(
          id: 'local-self',
          recipientType: RecipientType.user,
          recipientId: me.id,
          userId: me.id,
          displayName: me.displayName,
          permissionStatus: PermissionStatus.accepted,
          responseStatus: ResponseStatus.noResponse,
        ),
      );
    }
    final next = ZonedSchedule.nextOccurrenceUtc(
      start: start,
      rule: input.repeat,
      timezone: input.timezone,
      afterUtc: now,
      inclusive: true,
    );
    return Alarm(
      id: current?.id ?? input.id!,
      creator: current?.creator ?? me.toPublic(),
      title: input.title,
      message: input.message,
      localDate: input.localDate,
      localTime: input.localTime,
      timezone: input.timezone,
      scheduledAt: ZonedSchedule.toUtc(start, input.timezone),
      repeat: input.repeat,
      status: next == null ? AlarmStatus.completed : AlarmStatus.scheduled,
      priority: input.priority,
      sound: input.sound,
      vibration: input.vibration,
      shareResponses: input.shareResponses,
      version: current?.version ?? 1,
      recipients: recipients,
      nextOccurrenceAt: next,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
  }

  static Alarm _copy(Alarm a, {DateTime? nextOccurrenceAt, AlarmStatus? status}) => Alarm(
    id: a.id,
    creator: a.creator,
    title: a.title,
    message: a.message,
    localDate: a.localDate,
    localTime: a.localTime,
    timezone: a.timezone,
    scheduledAt: a.scheduledAt,
    repeat: a.repeat,
    triggerType: a.triggerType,
    status: status ?? a.status,
    priority: a.priority,
    sound: a.sound,
    vibration: a.vibration,
    shareResponses: a.shareResponses,
    version: a.version,
    recipients: a.recipients,
    nextOccurrenceAt: nextOccurrenceAt,
    createdAt: a.createdAt,
    updatedAt: DateTime.now().toUtc(),
    deletedAt: a.deletedAt,
  );
}
