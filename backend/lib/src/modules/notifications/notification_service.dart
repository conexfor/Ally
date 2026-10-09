import 'dart:async';

import 'package:logging/logging.dart';
import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import 'push_sender.dart';

const notificationColumns =
    'n.id::text AS id, n.type, n.title, n.body, n.data, n.alarm_id::text AS alarm_id, '
    'n.read_at, n.created_at';

AppNotification notificationFromRow(Row row) => AppNotification(
      id: row['id'] as String,
      type: NotificationType.fromWire(row['type'] as String),
      title: row['title'] as String,
      body: row['body'] as String,
      data: Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
      alarmId: row['alarm_id'] as String?,
      readAt: row['read_at'] as DateTime?,
      createdAt: row['created_at'] as DateTime,
    );

/// Notificación a crear (se guarda en la bandeja y se envía por push).
class OutgoingNotification {
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, String> data;
  final String? alarmId;

  /// Clave única: la misma notificación nunca se crea ni se envía dos veces.
  final String dedupeKey;

  const OutgoingNotification({
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.dedupeKey,
    this.data = const {},
    this.alarmId,
  });
}

class NotificationService {
  final Db db;
  final PushSender push;
  final _log = Logger('NotificationService');

  NotificationService(this.db, this.push);

  /// Tipos que afectan a alarmas programadas: se envían como mensajes de
  /// datos de prioridad alta para que la app sincronice y reprograme.
  static const _alarmTypes = {
    NotificationType.alarmNew,
    NotificationType.alarmRequest,
    NotificationType.alarmUpdated,
    NotificationType.alarmCancelled,
  };

  /// Guarda las notificaciones (ignorando duplicadas) y envía los push en
  /// segundo plano. Llamar después de confirmar la transacción.
  Future<void> notifyAll(List<OutgoingNotification> notifications) async {
    final created = <OutgoingNotification>[];
    for (final n in notifications) {
      final row = await db.one(
        '''
        INSERT INTO notifications (user_id, type, title, body, data, alarm_id, dedupe_key)
        VALUES (@user::uuid, @type, @title, @body, @data::jsonb, @alarm::uuid, @key)
        ON CONFLICT (dedupe_key) DO NOTHING
        RETURNING id
        ''',
        {
          'user': n.userId,
          'type': n.type.wire,
          'title': n.title,
          'body': n.body,
          'data': jsonParam(n.data),
          'alarm': n.alarmId,
          'key': n.dedupeKey,
        },
      );
      if (row != null) created.add(n);
    }
    if (created.isNotEmpty) unawaited(_dispatch(created));
  }

  Future<void> notify(OutgoingNotification notification) => notifyAll([notification]);

  /// Avisa a los otros dispositivos del usuario de que hay cambios (sin
  /// crear notificación visible).
  Future<void> requestSync(String userId, {String? excludeDeviceId}) async {
    final tokens = await _tokensFor([userId], excludeDeviceId: excludeDeviceId);
    if (tokens.isEmpty) return;
    unawaited(_send([
      for (final t in tokens[userId] ?? const <String>[])
        PushMessage(
          token: t,
          title: '',
          body: '',
          data: {'type': NotificationType.syncRequired.wire},
          dataOnly: true,
        ),
    ]));
  }

  Future<void> _dispatch(List<OutgoingNotification> notifications) async {
    try {
      final userIds = {for (final n in notifications) n.userId}.toList();
      final tokens = await _tokensFor(userIds);
      final settings = await _settingsFor(userIds);
      final messages = <PushMessage>[];
      for (final n in notifications) {
        final dataOnly = _alarmTypes.contains(n.type);
        final allowed = _allowedBySettings(n.type, settings[n.userId]);
        // Los avisos de alarmas siempre se envían (la app los necesita para
        // reprogramar); si el usuario los desactivó, sin mostrar nada.
        if (!dataOnly && !allowed) continue;
        for (final token in tokens[n.userId] ?? const <String>[]) {
          messages.add(PushMessage(
            token: token,
            title: n.title,
            body: n.body,
            dataOnly: dataOnly,
            data: {
              ...n.data,
              'type': n.type.wire,
              if (n.alarmId != null) 'alarm_id': n.alarmId!,
              if (dataOnly && !allowed) 'silent': 'true',
            },
          ));
        }
      }
      await _send(messages);
      await db.execute(
        'UPDATE notifications SET pushed_at = now() WHERE dedupe_key = ANY(@keys::text[])',
        {'keys': [for (final n in notifications) n.dedupeKey]},
      );
    } catch (e, st) {
      _log.warning('No se pudieron enviar notificaciones push', e, st);
    }
  }

  Future<void> _send(List<PushMessage> messages) async {
    if (messages.isEmpty) return;
    final invalid = await push.send(messages);
    if (invalid.isNotEmpty) {
      await db.execute(
        'UPDATE devices SET push_token = NULL WHERE push_token = ANY(@t::text[])',
        {'t': invalid.toList()},
      );
    }
  }

  bool _allowedBySettings(NotificationType type, UserSettings? s) {
    final settings = s ?? const UserSettings();
    return switch (type) {
      NotificationType.alarmNew ||
      NotificationType.alarmRequest ||
      NotificationType.alarmUpdated ||
      NotificationType.alarmCancelled =>
        settings.notifyNewAlarms,
      NotificationType.alarmConfirmed ||
      NotificationType.alarmSnoozed ||
      NotificationType.alarmDismissed =>
        settings.notifyResponses,
      NotificationType.connectionRequest ||
      NotificationType.connectionAccepted ||
      NotificationType.groupInvitation =>
        settings.notifyConnectionRequests,
      _ => true,
    };
  }

  Future<Map<String, List<String>>> _tokensFor(List<String> userIds, {String? excludeDeviceId}) async {
    final rows = await db.query(
      '''
      SELECT user_id::text AS user_id, push_token FROM devices
      WHERE user_id = ANY(@ids::uuid[]) AND is_active AND push_token IS NOT NULL
        AND (@exclude::uuid IS NULL OR id <> @exclude::uuid)
      ''',
      {'ids': userIds, 'exclude': excludeDeviceId},
    );
    final result = <String, List<String>>{};
    for (final r in rows) {
      result.putIfAbsent(r['user_id'] as String, () => []).add(r['push_token'] as String);
    }
    return result;
  }

  Future<Map<String, UserSettings>> _settingsFor(List<String> userIds) async {
    final rows = await db.query(
      'SELECT user_id::text AS uid, * FROM user_settings WHERE user_id = ANY(@ids::uuid[])',
      {'ids': userIds},
    );
    return {for (final r in rows) r['uid'] as String: UserSettings.fromJson(r)};
  }

  // ------------------------------------------------------------ bandeja

  Future<List<AppNotification>> list(String userId, {int limit = 50, DateTime? before}) async {
    final rows = await db.query(
      '''
      SELECT $notificationColumns FROM notifications n
      WHERE n.user_id = @u::uuid AND (@before::timestamptz IS NULL OR n.created_at < @before::timestamptz)
      ORDER BY n.created_at DESC LIMIT @limit
      ''',
      {'u': userId, 'before': before, 'limit': limit},
    );
    return [for (final r in rows) notificationFromRow(r)];
  }

  Future<int> unreadCount(String userId) async {
    final row = await db.one(
      'SELECT count(*)::int AS c FROM notifications WHERE user_id = @u::uuid AND read_at IS NULL',
      {'u': userId},
    );
    return row!['c'] as int;
  }

  /// Solo modifica notificaciones del propio usuario.
  Future<bool> markRead(String userId, String id) async =>
      await db.execute(
        'UPDATE notifications SET read_at = now() WHERE id = @id::uuid AND user_id = @u::uuid AND read_at IS NULL',
        {'id': id, 'u': userId},
      ) >
      0;

  Future<void> markAllRead(String userId) => db.execute(
        'UPDATE notifications SET read_at = now() WHERE user_id = @u::uuid AND read_at IS NULL',
        {'u': userId},
      );
}
