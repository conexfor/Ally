import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../../http/request_utils.dart';
import '../notifications/notification_service.dart';
import 'alarms_service.dart';

/// Rutinas: alarmas encadenadas (07:00 Despertar → 07:15 Prepararse → ...).
/// Cada paso es una alarma normal (mismos permisos, respuestas y
/// sincronización); la rutina las agrupa y permite borrarlas juntas.
class SequencesService {
  final Db db;
  final AlarmsService alarms;
  final NotificationService notifications;

  SequencesService(this.db, this.alarms, this.notifications);

  static const minSteps = 2;
  static const maxSteps = 12;

  Future<List<AlarmSequence>> list(String me) async {
    final rows = await db.query(
      '''
      SELECT s.id::text AS id, s.name, s.created_at, si.position, si.offset_minutes,
             a.id::text AS alarm_id, a.title, to_char(a.local_time, 'HH24:MI') AS local_time
      FROM alarm_sequences s
      JOIN alarm_sequence_items si ON si.sequence_id = s.id
      JOIN alarms a ON a.id = si.alarm_id AND a.deleted_at IS NULL
      WHERE s.owner_id = @me::uuid AND s.deleted_at IS NULL
      ORDER BY s.created_at DESC, si.position
      ''',
      {'me': me},
    );
    final byId = <String, ({String name, DateTime createdAt, List<AlarmSequenceStep> steps})>{};
    for (final r in rows) {
      final entry = byId.putIfAbsent(
        r['id'] as String,
        () => (name: r['name'] as String, createdAt: r['created_at'] as DateTime, steps: []),
      );
      entry.steps.add(AlarmSequenceStep(
        alarmId: r['alarm_id'] as String,
        position: r['position'] as int,
        offsetMinutes: r['offset_minutes'] as int,
        title: r['title'] as String,
        localTime: LocalTime.parse(r['local_time'] as String),
      ));
    }
    return [
      for (final e in byId.entries)
        AlarmSequence(id: e.key, name: e.value.name, steps: e.value.steps, createdAt: e.value.createdAt),
    ];
  }

  Future<AlarmSequence> create(String me, SequenceInput input, {String? deviceId}) async {
    _validate(input);
    final first = input.steps.first.localTime.minutesOfDay;
    final created = <Alarm>[];
    try {
      for (final step in input.steps) {
        created.add(await alarms.create(
          me,
          AlarmInput(
            title: step.title,
            message: step.message,
            localDate: input.localDate,
            localTime: step.localTime,
            timezone: input.timezone,
            repeat: input.repeat,
            recipients: input.recipients,
          ),
          deviceId: deviceId,
          notify: false,
        ));
      }
    } catch (_) {
      // Todo o nada: si un paso falla (p. ej. permisos) se deshacen los creados.
      for (final alarm in created) {
        await db.execute('DELETE FROM alarms WHERE id = @id::uuid', {'id': alarm.id});
      }
      rethrow;
    }

    final sequenceId = await db.transaction((tx) async {
      final row = await tx.one(
        'INSERT INTO alarm_sequences (owner_id, name) VALUES (@me::uuid, @n) RETURNING id::text AS id',
        {'me': me, 'n': input.name},
      );
      final id = row!['id'] as String;
      for (final (i, alarm) in created.indexed) {
        await tx.execute(
          'INSERT INTO alarm_sequence_items (sequence_id, alarm_id, position, offset_minutes) '
          'VALUES (@s::uuid, @a::uuid, @p, @o)',
          {'s': id, 'a': alarm.id, 'p': i, 'o': input.steps[i].localTime.minutesOfDay - first},
        );
      }
      // Fuerza que los clientes reciban las alarmas con la rutina asociada.
      await tx.execute(
        'UPDATE alarms SET updated_at = now() WHERE id = ANY(@ids::uuid[])',
        {'ids': [for (final a in created) a.id]},
      );
      return id;
    });

    await _notifyRecipients(me, created.first, input);
    return (await list(me)).firstWhere((s) => s.id == sequenceId);
  }

  Future<void> delete(String me, String sequenceId, {String? deviceId}) async {
    final rows = await db.query(
      '''
      SELECT si.alarm_id::text AS alarm_id FROM alarm_sequences s
      JOIN alarm_sequence_items si ON si.sequence_id = s.id
      WHERE s.id = @id::uuid AND s.owner_id = @me::uuid AND s.deleted_at IS NULL
      ''',
      {'id': sequenceId, 'me': me},
    );
    if (rows.isEmpty) throw const ApiException.notFound('No encontramos esa rutina.');
    for (final r in rows) {
      try {
        await alarms.delete(me, r['alarm_id'] as String, deviceId: deviceId);
      } on ApiException catch (e) {
        if (e.status != 404) rethrow;
      }
    }
    await db.execute('UPDATE alarm_sequences SET deleted_at = now() WHERE id = @id::uuid', {'id': sequenceId});
  }

  void _validate(SequenceInput input) {
    final errors = FieldErrors();
    if (input.name.isEmpty || input.name.length > 60) {
      errors.add('name', 'Escribe un nombre para la rutina (máximo 60 caracteres).');
    }
    if (input.steps.length < minSteps || input.steps.length > maxSteps) {
      errors.add('steps', 'Una rutina tiene entre $minSteps y $maxSteps pasos.');
    }
    for (final (i, step) in input.steps.indexed) {
      final error = Validators.alarmTitle(step.title) ?? Validators.alarmMessage(step.message);
      if (error != null) errors.add('steps', 'Paso ${i + 1}: $error');
      if (i > 0 && !step.localTime.isAfter(input.steps[i - 1].localTime)) {
        errors.add('steps', 'Los pasos deben ir en orden de hora dentro del mismo día.');
      }
    }
    errors.throwIfAny();
  }

  Future<void> _notifyRecipients(String me, Alarm first, SequenceInput input) async {
    await notifications.notifyAll([
      for (final r in first.recipients)
        if (r.recipientType == RecipientType.user && r.userId != null && r.userId != me)
          OutgoingNotification(
            userId: r.userId!,
            type: r.permissionStatus == PermissionStatus.accepted
                ? NotificationType.alarmNew
                : NotificationType.alarmRequest,
            title: 'Nueva rutina de ${first.creator.displayName}',
            body: '«${input.name}»: ${input.steps.length} alarmas desde las '
                '${SpanishFormatter.shortTime(input.steps.first.localTime)}.',
            alarmId: first.id,
            dedupeKey: 'sequence_new:${first.id}:${r.userId}',
          ),
    ]);
  }
}

/// `/api/sequences`
Router sequencesRoutes(SequencesService sequences) {
  final router = Router();
  router.get('/', (Request req) async {
    final list = await sequences.list(req.userId);
    return jsonResponse({'sequences': [for (final s in list) s.toJson()]});
  });
  router.post('/', (Request req) async {
    final input = await req.readBody(SequenceInput.fromJson);
    return jsonResponse((await sequences.create(req.userId, input, deviceId: req.deviceId)).toJson(), status: 201);
  });
  router.delete('/<id>', (Request req, String id) async {
    await sequences.delete(req.userId, requireUuid(id), deviceId: req.deviceId);
    return noContent();
  });
  return router;
}
