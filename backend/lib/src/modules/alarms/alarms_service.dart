import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../notifications/notification_service.dart';
import '../users/users_repository.dart';
import 'alarms_repository.dart';
import 'recipient_planner.dart';

/// Reglas de negocio de las alarmas. Todas las operaciones verifican que el
/// usuario sea el creador o un destinatario; cambiar un ID en la URL nunca
/// da acceso a alarmas ajenas (se responde 404).
class AlarmsService {
  final Db db;
  final RecipientPlanner planner;
  final NotificationService notifications;
  final DateTime Function() _now;

  AlarmsService(this.db, this.planner, this.notifications, {DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc());

  AlarmsRepository get _repo => AlarmsRepository(db);

  static const _notFound = ApiException.notFound('No encontramos esa alarma.');

  /// Tolerancia para alarmas creadas sin conexión que llegan tarde.
  static const _offlineGrace = Duration(minutes: 2);

  Future<List<Alarm>> list(String me, {String scope = 'all', DateTime? from, DateTime? to}) =>
      _repo.listVisible(me, scope: scope, from: from, to: to);

  Future<Alarm> get(String me, String id) async =>
      await _repo.findVisible(me, id) ?? (throw _notFound);

  // ------------------------------------------------------------- crear

  /// [notify]: avisar a cada destinatario (las rutinas envían un aviso único).
  Future<Alarm> create(String me, AlarmInput input, {String? deviceId, bool notify = true}) async {
    _validate(input);
    if (input.id != null) {
      if (!Validators.isUuid(input.id)) {
        throw const ApiException.badRequest('El identificador de la alarma no es válido.');
      }
      // Idempotencia: reenviar una alarma ya creada (p. ej. desde la cola
      // offline) devuelve la existente.
      final existing = await _repo.findRecord(input.id!);
      if (existing != null) {
        if (existing.creatorId != me) throw const ApiException.conflict('Ese identificador ya está en uso.');
        return get(me, input.id!);
      }
    }

    final schedule = _schedule(input, allowPast: input.id != null);
    final (alarmId, planned) = await db.transaction((tx) async {
      final row = await tx.one(
        '''
        INSERT INTO alarms (id, creator_id, title, message, local_date, local_time, timezone, scheduled_at,
                            next_occurrence_at, repeat_rule, status, priority, sound, vibration, share_responses)
        VALUES (COALESCE(@id::uuid, gen_random_uuid()), @me::uuid, @title, @message, @date::date, @time::time,
                @tz, @scheduled, @next, @repeat::jsonb, @status, @priority, @sound, @vibration, @share)
        RETURNING id::text AS id
        ''',
        {
          'id': input.id,
          'me': me,
          ..._alarmParams(input, schedule),
        },
      );
      final id = row!['id'] as String;
      final planned = await planner.plan(tx, me, input.recipients);
      await _insertRecipients(tx, id, planned);
      return (id, planned);
    });

    final alarm = await get(me, alarmId);
    if (notify) await _notifyNewRecipients(me, alarm, planned);
    await notifications.requestSync(me, excludeDeviceId: deviceId);
    return alarm;
  }

  // ------------------------------------------------------------ editar

  Future<Alarm> update(String me, String id, AlarmInput input, {String? deviceId}) async {
    _validate(input);
    final record = await _requireCreator(me, id);
    if (record.isDeleted) throw _notFound;
    if (input.baseVersion != null && input.baseVersion != record.version) {
      throw const ApiException.conflict(
        'La alarma cambió desde otro dispositivo. Revisa la versión actual.',
        code: 'version_conflict',
      );
    }
    final schedule = _schedule(input, allowPast: false);
    final scheduleChanged = record.start != input.localDate.at(input.localTime) ||
        record.timezone != input.timezone ||
        record.repeat != input.repeat;

    final newRecipients = await db.transaction((tx) async {
      final updated = await tx.execute(
        '''
        UPDATE alarms SET title = @title, message = @message, local_date = @date::date, local_time = @time::time,
          timezone = @tz, scheduled_at = @scheduled, next_occurrence_at = @next, repeat_rule = @repeat::jsonb,
          status = @status, priority = @priority, sound = @sound, vibration = @vibration,
          share_responses = @share, version = version + 1
        WHERE id = @id::uuid AND version = @version
        ''',
        {'id': id, 'version': record.version, ..._alarmParams(input, schedule)},
      );
      if (updated == 0) {
        throw const ApiException.conflict(
          'La alarma cambió desde otro dispositivo. Revisa la versión actual.',
          code: 'version_conflict',
        );
      }
      final planned = await planner.plan(tx, me, input.recipients);
      final existing = {
        for (final r in await tx.query(
          "SELECT recipient_type || ':' || recipient_id AS key FROM alarm_recipients WHERE alarm_id = @id::uuid",
          {'id': id},
        ))
          r['key'] as String,
      };
      final keep = {for (final p in planned) p.key};
      await tx.execute(
        "DELETE FROM alarm_recipients WHERE alarm_id = @id::uuid "
        "AND NOT (recipient_type || ':' || recipient_id = ANY(@keep::text[]))",
        {'id': id, 'keep': keep.toList()},
      );
      final added = planned.where((p) => !existing.contains(p.key)).toList();
      await _insertRecipients(tx, id, added);
      if (scheduleChanged) {
        await tx.execute(
          "UPDATE alarm_recipients SET response_status = 'no_response', responded_at = NULL "
          "WHERE alarm_id = @id::uuid AND response_status <> 'no_response'",
          {'id': id},
        );
      }
      return added;
    });

    final alarm = await get(me, id);
    final addedUsers = {for (final p in newRecipients) p.userId};
    await notifications.notifyAll([
      for (final r in alarm.recipients)
        if (r.userId != null &&
            r.userId != me &&
            !addedUsers.contains(r.userId) &&
            r.permissionStatus == PermissionStatus.accepted)
          OutgoingNotification(
            userId: r.userId!,
            type: NotificationType.alarmUpdated,
            title: 'Alarma modificada',
            body: '${alarm.creator.displayName} cambió "${alarm.title}".',
            alarmId: id,
            dedupeKey: 'alarm_updated:$id:${alarm.version}:${r.userId}',
          ),
    ]);
    await _notifyNewRecipients(me, alarm, newRecipients);
    await notifications.requestSync(me, excludeDeviceId: deviceId);
    return alarm;
  }

  // ---------------------------------------------------------- eliminar

  /// El creador elimina la alarma para todos; un destinatario solo deja de
  /// recibirla.
  Future<void> delete(String me, String id, {String? deviceId}) async {
    final record = await _repo.findRecord(id);
    if (record == null) throw _notFound;
    if (record.creatorId != me) {
      final updated = await db.execute(
        "UPDATE alarm_recipients SET permission_status = 'rejected' "
        "WHERE alarm_id = @id::uuid AND user_id = @me::uuid AND permission_status <> 'rejected'",
        {'id': id, 'me': me},
      );
      if (updated == 0) throw _notFound;
      await notifications.requestSync(me, excludeDeviceId: deviceId);
      return;
    }
    if (record.isDeleted) return;
    final alarm = await get(me, id);
    await db.execute(
      "UPDATE alarms SET deleted_at = now(), status = 'cancelled', next_occurrence_at = NULL WHERE id = @id::uuid",
      {'id': id},
    );
    await _notifyCancelled(me, alarm, 'alarm_deleted:$id');
    await notifications.requestSync(me, excludeDeviceId: deviceId);
  }

  /// Cancela la próxima ocurrencia. Si no es recurrente, la alarma queda
  /// cancelada. Para un destinatario equivale a descartar su próxima ocurrencia.
  Future<Alarm> cancelNext(String me, String id, {String? deviceId}) async {
    final alarm = await get(me, id);
    final next = alarm.nextOccurrenceAt;
    if (next == null || !alarm.isActive) {
      throw const ApiException.conflict('Esta alarma ya no tiene próximas ocurrencias.');
    }
    if (alarm.creator.id != me) {
      return respond(
        me,
        id,
        RespondInput(occurrenceAt: next, response: ResponseStatus.dismissed, deviceId: deviceId),
      );
    }
    final record = (await _repo.findRecord(id))!;
    final following = ZonedSchedule.nextOccurrenceUtc(
      start: record.start,
      rule: record.repeat,
      timezone: record.timezone,
      afterUtc: next,
    );
    await db.transaction((tx) async {
      await tx.execute(
        "INSERT INTO alarm_occurrences (alarm_id, scheduled_for, status) VALUES (@id::uuid, @at, 'cancelled') "
        "ON CONFLICT (alarm_id, scheduled_for) DO UPDATE SET status = 'cancelled'",
        {'id': id, 'at': next},
      );
      await tx.execute(
        'UPDATE alarms SET next_occurrence_at = @next, '
        "status = CASE WHEN @next::timestamptz IS NULL THEN 'cancelled' ELSE 'scheduled' END "
        'WHERE id = @id::uuid',
        {'id': id, 'next': following},
      );
    });
    final updated = await get(me, id);
    await _notifyCancelled(me, alarm, 'alarm_cancelled:$id:${next.millisecondsSinceEpoch}',
        occurrenceOnly: following != null);
    await notifications.requestSync(me, excludeDeviceId: deviceId);
    return updated;
  }

  // --------------------------------------------------------- responder

  Future<Alarm> respond(String me, String id, RespondInput input, {String? deviceId}) async {
    if (input.response == ResponseStatus.noResponse || input.response == ResponseStatus.expired) {
      throw const ApiException.badRequest('Respuesta no válida.');
    }
    final record = await _repo.findRecord(id);
    if (record == null || record.isDeleted) throw _notFound;
    final recipientRow = await db.one(
      '''
      SELECT id::text AS id, permission_status FROM alarm_recipients
      WHERE alarm_id = @id::uuid AND user_id = @me::uuid AND recipient_type = 'user'
      ''',
      {'id': id, 'me': me},
    );
    if (recipientRow == null) {
      if (record.creatorId == me) {
        throw const ApiException.badRequest('No eres destinatario de esta alarma.');
      }
      throw _notFound;
    }
    if (recipientRow['permission_status'] != 'accepted') {
      throw const ApiException.conflict('Primero acepta la alarma.');
    }

    final occurrenceAt = input.occurrenceAt.toUtc();
    final isOccurrence = ZonedSchedule.nextOccurrenceUtc(
          start: record.start,
          rule: record.repeat,
          timezone: record.timezone,
          afterUtc: occurrenceAt.subtract(const Duration(seconds: 1)),
        ) ==
        occurrenceAt;
    if (!isOccurrence) throw const ApiException.badRequest('Esa ocurrencia no existe.');

    int? snoozeMinutes;
    if (input.response == ResponseStatus.snoozed) {
      snoozeMinutes = input.snoozeMinutes ?? await _defaultSnooze(me);
      if (snoozeMinutes < 1 || snoozeMinutes > 24 * 60) {
        throw const ApiException.badRequest('Puedes posponer entre 1 minuto y 24 horas.');
      }
    }
    final now = _now();
    await db.transaction((tx) async {
      final occurrence = await tx.one(
        '''
        INSERT INTO alarm_occurrences (alarm_id, scheduled_for, status) VALUES (@id::uuid, @at, 'triggered')
        ON CONFLICT (alarm_id, scheduled_for) DO UPDATE SET scheduled_for = EXCLUDED.scheduled_for
        RETURNING id::text AS id
        ''',
        {'id': id, 'at': occurrenceAt},
      );
      await tx.execute(
        '''
        INSERT INTO alarm_responses (occurrence_id, user_id, device_id, response, snoozed_until, responded_at)
        VALUES (@occ::uuid, @me::uuid, (SELECT id FROM devices WHERE id = @device::uuid AND user_id = @me::uuid),
                @response, @snoozed, @now)
        ON CONFLICT (occurrence_id, user_id) DO UPDATE SET
          response = EXCLUDED.response, snoozed_until = EXCLUDED.snoozed_until,
          responded_at = EXCLUDED.responded_at, device_id = EXCLUDED.device_id
        ''',
        {
          'occ': occurrence!['id'],
          'me': me,
          'device': input.deviceId ?? deviceId,
          'response': input.response.wire,
          'snoozed': snoozeMinutes == null ? null : now.add(Duration(minutes: snoozeMinutes)),
          'now': now,
        },
      );
      await tx.execute(
        'UPDATE alarm_recipients SET response_status = @response, responded_at = @now WHERE id = @r::uuid',
        {'r': recipientRow['id'], 'response': input.response.wire, 'now': now},
      );
    });

    if (record.creatorId != me && await _sharesResponses(me, record.creatorId, id)) {
      final user = await UsersRepository(db).findById(me);
      final name = user?.displayName ?? 'Un destinatario';
      final (type, verb) = switch (input.response) {
        ResponseStatus.confirmed => (NotificationType.alarmConfirmed, 'confirmó'),
        ResponseStatus.snoozed => (NotificationType.alarmSnoozed, 'pospuso'),
        _ => (NotificationType.alarmDismissed, 'descartó'),
      };
      await notifications.notify(OutgoingNotification(
        userId: record.creatorId,
        type: type,
        title: record.title,
        body: '$name $verb la alarma.',
        alarmId: id,
        data: {'responder_id': me, 'occurrence_at': occurrenceAt.toIso8601String()},
        dedupeKey: 'alarm_response:$id:${occurrenceAt.millisecondsSinceEpoch}:$me:${input.response.wire}',
      ));
    }
    // Los otros dispositivos del usuario dejan de sonar al sincronizar.
    await notifications.requestSync(me, excludeDeviceId: input.deviceId ?? deviceId);
    return get(me, id);
  }

  /// Aceptar o rechazar una alarma pendiente recibida.
  Future<Alarm?> setPermission(String me, String id, {required bool accept, String? deviceId}) async {
    final updated = await db.execute(
      "UPDATE alarm_recipients SET permission_status = @status "
      "WHERE alarm_id = @id::uuid AND user_id = @me::uuid AND recipient_type = 'user' "
      "AND permission_status = 'pending' "
      'AND EXISTS (SELECT 1 FROM alarms WHERE id = @id::uuid AND deleted_at IS NULL)',
      {'id': id, 'me': me, 'status': accept ? 'accepted' : 'rejected'},
    );
    if (updated == 0) throw _notFound;
    await notifications.requestSync(me, excludeDeviceId: deviceId);
    return accept ? get(me, id) : null;
  }

  /// Respuestas de una alarma visibles para el usuario.
  Future<List<AlarmResponse>> responses(String me, String id) async {
    await get(me, id);
    return _repo.visibleResponses(me, alarmId: id);
  }

  /// Activa o desactiva un dispositivo propio para una alarma concreta.
  Future<void> setDevicePreference(String me, String id, String deviceId, bool enabled) async {
    await get(me, id);
    final updated = await db.execute(
      '''
      INSERT INTO alarm_device_preferences (alarm_id, device_id, enabled)
      SELECT @id::uuid, d.id, @enabled FROM devices d WHERE d.id = @d::uuid AND d.user_id = @me::uuid
      ON CONFLICT (alarm_id, device_id) DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = now()
      ''',
      {'id': id, 'd': deviceId, 'me': me, 'enabled': enabled},
    );
    if (updated == 0) throw const ApiException.notFound('No encontramos ese dispositivo.');
    // Marca la alarma como cambiada para que se sincronice.
    await db.execute('UPDATE alarm_recipients SET updated_at = now() '
        'WHERE alarm_id = @id::uuid AND user_id = @me::uuid', {'id': id, 'me': me});
  }

  /// Preferencias de dispositivo del usuario (alarm_id → device_id → enabled).
  Future<Map<String, Map<String, bool>>> devicePreferences(String me) async {
    final rows = await db.query(
      '''
      SELECT p.alarm_id::text AS alarm_id, p.device_id::text AS device_id, p.enabled
      FROM alarm_device_preferences p JOIN devices d ON d.id = p.device_id
      WHERE d.user_id = @me::uuid
      ''',
      {'me': me},
    );
    final result = <String, Map<String, bool>>{};
    for (final r in rows) {
      result.putIfAbsent(r['alarm_id'] as String, () => {})[r['device_id'] as String] =
          r['enabled'] as bool;
    }
    return result;
  }

  // ------------------------------------------------------------ internos

  void _validate(AlarmInput input) {
    final errors = FieldErrors()
      ..check('title', Validators.alarmTitle(input.title))
      ..check('message', Validators.alarmMessage(input.message));
    if (!ZonedSchedule.isValidTimezone(input.timezone)) {
      errors.add('timezone', 'La zona horaria no es válida.');
    }
    if (input.sound.length > 60) errors.add('sound', 'El sonido no es válido.');
    errors.throwIfAny();
  }

  ({DateTime scheduledAt, DateTime? next, AlarmStatus status}) _schedule(
    AlarmInput input, {
    required bool allowPast,
  }) {
    final start = input.localDate.at(input.localTime);
    final scheduledAt = ZonedSchedule.toUtc(start, input.timezone);
    final now = _now();
    if (scheduledAt.isAfter(now.add(const Duration(days: 366 * 2)))) {
      throw ApiException.validation({'local_date': 'Solo se admiten alarmas con hasta 2 años de antelación.'});
    }
    final next = ZonedSchedule.nextOccurrenceUtc(
      start: start,
      rule: input.repeat,
      timezone: input.timezone,
      afterUtc: now.subtract(_offlineGrace),
      inclusive: true,
    );
    if (next == null && !allowPast) {
      throw ApiException.validation({'local_time': 'La fecha y hora indicadas ya pasaron.'});
    }
    return (
      scheduledAt: scheduledAt,
      next: next,
      status: next == null ? AlarmStatus.completed : AlarmStatus.scheduled,
    );
  }

  Map<String, Object?> _alarmParams(
    AlarmInput input,
    ({DateTime scheduledAt, DateTime? next, AlarmStatus status}) schedule,
  ) =>
      {
        'title': input.title.trim(),
        'message': (input.message?.trim().isEmpty ?? true) ? null : input.message!.trim(),
        'date': input.localDate.toString(),
        'time': input.localTime.toString(),
        'tz': input.timezone,
        'scheduled': schedule.scheduledAt,
        'next': schedule.next,
        'repeat': jsonParam(input.repeat?.toJson()),
        'status': schedule.status.wire,
        'priority': input.priority.wire,
        'sound': input.sound,
        'vibration': input.vibration,
        'share': input.shareResponses,
      };

  Future<void> _insertRecipients(Db tx, String alarmId, List<PlannedRecipient> planned) async {
    for (final p in planned) {
      await tx.execute(
        '''
        INSERT INTO alarm_recipients (alarm_id, recipient_type, recipient_id, user_id, source_group_id, permission_status)
        VALUES (@a::uuid, @type, @rid::uuid, @uid::uuid, @gid::uuid, @perm)
        ON CONFLICT (alarm_id, recipient_type, recipient_id) DO NOTHING
        ''',
        {
          'a': alarmId,
          'type': p.type.wire,
          'rid': p.recipientId,
          'uid': p.userId,
          'gid': p.sourceGroupId,
          'perm': p.permission.wire,
        },
      );
    }
  }

  Future<AlarmRecord> _requireCreator(String me, String id) async {
    final record = await _repo.findRecord(id);
    if (record == null) throw _notFound;
    if (record.creatorId != me) {
      // Si es destinatario sabe que existe: 403; si no, 404.
      final visible = await _repo.findVisible(me, id);
      if (visible == null) throw _notFound;
      throw const ApiException.forbidden('Solo quien creó la alarma puede modificarla.');
    }
    return record;
  }

  Future<void> _notifyNewRecipients(String me, Alarm alarm, List<PlannedRecipient> planned) async {
    final when = _describeWhen(alarm);
    await notifications.notifyAll([
      for (final p in planned)
        if (p.type == RecipientType.user && p.userId != null && p.userId != me)
          p.permission == PermissionStatus.accepted
              ? OutgoingNotification(
                  userId: p.userId!,
                  type: NotificationType.alarmNew,
                  title: 'Nueva alarma de ${alarm.creator.displayName}',
                  body: '${alarm.title} · $when',
                  alarmId: alarm.id,
                  dedupeKey: 'alarm_new:${alarm.id}:${p.userId}',
                )
              : OutgoingNotification(
                  userId: p.userId!,
                  type: NotificationType.alarmRequest,
                  title: '${alarm.creator.displayName} quiere enviarte una alarma',
                  body: '${alarm.title} · $when. Ábrela para aceptarla o rechazarla.',
                  alarmId: alarm.id,
                  dedupeKey: 'alarm_request:${alarm.id}:${p.userId}',
                ),
    ]);
  }

  Future<void> _notifyCancelled(String me, Alarm alarm, String keyPrefix, {bool occurrenceOnly = false}) =>
      notifications.notifyAll([
        for (final r in alarm.recipients)
          if (r.userId != null && r.userId != me && r.permissionStatus != PermissionStatus.rejected)
            OutgoingNotification(
              userId: r.userId!,
              type: NotificationType.alarmCancelled,
              title: occurrenceOnly ? 'Alarma omitida' : 'Alarma cancelada',
              body: occurrenceOnly
                  ? '${alarm.creator.displayName} canceló la próxima vez de "${alarm.title}".'
                  : '${alarm.creator.displayName} canceló "${alarm.title}".',
              alarmId: alarm.id,
              dedupeKey: '$keyPrefix:${r.userId}',
            ),
      ]);

  String _describeWhen(Alarm alarm) {
    final next = alarm.nextOccurrenceAt;
    if (next == null) return SpanishFormatter.shortTime(alarm.localTime);
    final local = ZonedSchedule.toLocal(next, alarm.timezone);
    final today = ZonedSchedule.toLocal(_now(), alarm.timezone).date;
    final repeat = alarm.repeat == null ? '' : ' (${SpanishFormatter.repeat(alarm.repeat!).toLowerCase()})';
    return '${SpanishFormatter.date(local.date, today)} a las ${SpanishFormatter.shortTime(local.time)}$repeat';
  }

  Future<int> _defaultSnooze(String me) async =>
      (await UsersRepository(db).getSettings(me)).defaultSnoozeMinutes;

  Future<bool> _sharesResponses(String me, String creatorId, String alarmId) async {
    final row = await db.one(
      '''
      SELECT COALESCE(p.share_response_status, true) AS share
      FROM alarm_recipients r
      LEFT JOIN connection_permissions p
        ON r.source_group_id IS NULL AND p.owner_id = r.user_id AND p.subject_id = @creator::uuid
      WHERE r.alarm_id = @id::uuid AND r.user_id = @me::uuid AND r.recipient_type = 'user'
      ''',
      {'id': alarmId, 'me': me, 'creator': creatorId},
    );
    return row?['share'] as bool? ?? false;
  }
}
