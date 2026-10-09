import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../users/users_repository.dart';

/// Condición SQL: el usuario `@me` puede ver la alarma `a` (es su creador o
/// un destinatario que no la rechazó).
const alarmVisibleSql = '''
  (a.creator_id = @me::uuid OR EXISTS (
     SELECT 1 FROM alarm_recipients vr
     WHERE vr.alarm_id = a.id AND vr.user_id = @me::uuid
       AND vr.recipient_type IN ('user', 'device') AND vr.permission_status <> 'rejected'))
''';

const _alarmColumns = '''
  a.id::text AS id, a.title, a.message, a.local_date::text AS local_date,
  to_char(a.local_time, 'HH24:MI') AS local_time, a.timezone, a.scheduled_at,
  a.next_occurrence_at, a.repeat_rule, a.trigger_type, a.status, a.priority, a.sound,
  a.vibration, a.share_responses, a.version, a.created_at, a.updated_at, a.deleted_at,
  a.sync_version, a.creator_id::text AS creator_id,
''';

/// Datos internos de una alarma (sin destinatarios).
class AlarmRecord {
  final Row row;
  AlarmRecord(this.row);

  String get id => row['id'] as String;
  String get creatorId => row['creator_id'] as String;
  String get title => row['title'] as String;
  String get timezone => row['timezone'] as String;
  int get version => row['version'] as int;
  bool get shareResponses => row['share_responses'] as bool;
  bool get isDeleted => row['deleted_at'] != null;
  AlarmStatus get status => AlarmStatus.fromWire(row['status'] as String);
  LocalDateTime get start => LocalDateTime(
        LocalDate.parse(row['local_date'] as String),
        LocalTime.parse(row['local_time'] as String),
      );
  RepeatRule? get repeat => row['repeat_rule'] == null
      ? null
      : RepeatRule.fromJson(Map<String, dynamic>.from(row['repeat_rule'] as Map));
  DateTime? get nextOccurrenceAt => row['next_occurrence_at'] as DateTime?;
}

class RecipientRecord {
  final AlarmRecipient recipient;

  /// El usuario permite al creador ver sus respuestas.
  final bool sharesWithCreator;
  RecipientRecord(this.recipient, this.sharesWithCreator);
}

class AlarmsRepository {
  final Db db;
  AlarmsRepository(this.db);

  Future<AlarmRecord?> findRecord(String alarmId) async {
    final row = await db.one(
      'SELECT $_alarmColumns 1 AS _ FROM alarms a WHERE a.id = @id::uuid',
      {'id': alarmId},
    );
    return row == null ? null : AlarmRecord(row);
  }

  /// Alarma visible para [me] (incluye eliminadas solo si [includeDeleted]).
  Future<Alarm?> findVisible(String me, String alarmId, {bool includeDeleted = false}) async {
    final alarms = await _load(
      me,
      'a.id = @id::uuid AND $alarmVisibleSql ${includeDeleted ? '' : 'AND a.deleted_at IS NULL'}',
      {'id': alarmId},
    );
    return alarms.isEmpty ? null : alarms.first;
  }

  /// Alarmas activas visibles, ordenadas por próxima ocurrencia.
  Future<List<Alarm>> listVisible(
    String me, {
    String scope = 'all',
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) {
    final scopeSql = switch (scope) {
      'created' => 'AND a.creator_id = @me::uuid',
      'received' => 'AND a.creator_id <> @me::uuid',
      _ => '',
    };
    return _load(
      me,
      '''
      $alarmVisibleSql AND a.deleted_at IS NULL $scopeSql
        AND (@from::timestamptz IS NULL OR a.next_occurrence_at >= @from::timestamptz)
        AND (@to::timestamptz IS NULL OR a.next_occurrence_at < @to::timestamptz)
      ''',
      {'from': from, 'to': to},
      orderBy: 'a.next_occurrence_at NULLS LAST, a.created_at DESC',
      limit: limit,
    );
  }

  /// Alarmas con cambios desde [cursor] (incluye lápidas: eliminadas o en las
  /// que el usuario ya no es destinatario).
  Future<(List<Alarm>, int maxVersion)> changedSince(String me, int cursor, {int limit = 300}) async {
    final rows = await db.query(
      '''
      SELECT a.id::text AS id,
             GREATEST(a.sync_version, COALESCE(MAX(r.sync_version), 0)) AS v
      FROM alarms a
      LEFT JOIN alarm_recipients r ON r.alarm_id = a.id
      WHERE (a.creator_id = @me::uuid OR EXISTS (
               SELECT 1 FROM alarm_recipients mr WHERE mr.alarm_id = a.id AND mr.user_id = @me::uuid))
      GROUP BY a.id
      HAVING GREATEST(a.sync_version, COALESCE(MAX(r.sync_version), 0)) > @cursor
      ORDER BY v
      LIMIT @limit
      ''',
      {'me': me, 'cursor': cursor, 'limit': limit},
    );
    if (rows.isEmpty) return (const <Alarm>[], cursor);
    final ids = [for (final r in rows) r['id'] as String];
    final maxVersion = rows.last['v'] as int;
    final alarms = await _load(
      me,
      '''a.id = ANY(@ids::uuid[]) AND (a.creator_id = @me::uuid OR EXISTS (
           SELECT 1 FROM alarm_recipients mr WHERE mr.alarm_id = a.id AND mr.user_id = @me::uuid))''',
      {'ids': ids},
      includeRejectedSelf: true,
    );
    return (alarms, maxVersion);
  }

  Future<List<Alarm>> _load(
    String me,
    String where,
    Map<String, Object?> params, {
    String orderBy = 'a.created_at',
    int limit = 500,
    bool includeRejectedSelf = false,
  }) async {
    final rows = await db.query(
      '''
      SELECT $_alarmColumns ${publicUserColumns('cu', 'creator')},
             s.id::text AS sequence_id, s.name AS sequence_name, si.position AS sequence_position
      FROM alarms a JOIN users cu ON cu.id = a.creator_id
      LEFT JOIN alarm_sequence_items si ON si.alarm_id = a.id
      LEFT JOIN alarm_sequences s ON s.id = si.sequence_id AND s.deleted_at IS NULL
      WHERE $where
      ORDER BY $orderBy
      LIMIT @limit
      ''',
      {...params, 'me': me, 'limit': limit},
    );
    if (rows.isEmpty) return const [];
    final recipients = await recipientsFor([for (final r in rows) r['id'] as String]);
    return [
      for (final row in rows)
        _toAlarm(row, _visibleRecipients(me, row, recipients[row['id']] ?? const [],
            includeRejectedSelf: includeRejectedSelf)),
    ];
  }

  /// Destinatarios de varias alarmas, con el nombre a mostrar.
  Future<Map<String, List<RecipientRecord>>> recipientsFor(List<String> alarmIds) async {
    final rows = await db.query(
      '''
      SELECT r.id::text AS id, r.alarm_id::text AS alarm_id, r.recipient_type,
             r.recipient_id::text AS recipient_id, r.user_id::text AS user_id,
             r.source_group_id::text AS source_group_id, r.permission_status, r.response_status,
             r.responded_at,
             COALESCE(u.display_name, g.name, d.device_name, '') AS display_name,
             COALESCE(p.share_response_status, true) AS shares_with_creator
      FROM alarm_recipients r
      JOIN alarms a ON a.id = r.alarm_id
      LEFT JOIN users u ON r.recipient_type = 'user' AND u.id = r.recipient_id
      LEFT JOIN groups g ON r.recipient_type = 'group' AND g.id = r.recipient_id
      LEFT JOIN devices d ON r.recipient_type = 'device' AND d.id = r.recipient_id
      LEFT JOIN connection_permissions p
        ON r.source_group_id IS NULL AND p.owner_id = r.user_id AND p.subject_id = a.creator_id
      WHERE r.alarm_id = ANY(@ids::uuid[])
      ORDER BY r.recipient_type DESC, display_name
      ''',
      {'ids': alarmIds},
    );
    final result = <String, List<RecipientRecord>>{};
    for (final r in rows) {
      result.putIfAbsent(r['alarm_id'] as String, () => []).add(RecipientRecord(
            AlarmRecipient(
              id: r['id'] as String,
              recipientType: RecipientType.fromWire(r['recipient_type'] as String),
              recipientId: r['recipient_id'] as String,
              displayName: r['display_name'] as String,
              userId: r['user_id'] as String?,
              sourceGroupId: r['source_group_id'] as String?,
              permissionStatus: PermissionStatus.fromWire(r['permission_status'] as String),
              responseStatus: ResponseStatus.fromWire(r['response_status'] as String),
              respondedAt: r['responded_at'] as DateTime?,
            ),
            r['shares_with_creator'] as bool,
          ));
    }
    return result;
  }

  /// Aplica la privacidad de respuestas:
  /// - El creador ve las respuestas de quien se las comparte.
  /// - Un destinatario se ve a sí mismo y, si el creador lo permite
  ///   (`share_responses`), al resto.
  List<AlarmRecipient> _visibleRecipients(
    String me,
    Row alarm,
    List<RecipientRecord> records, {
    required bool includeRejectedSelf,
  }) {
    final isCreator = alarm['creator_id'] == me;
    final shareResponses = alarm['share_responses'] as bool;
    final result = <AlarmRecipient>[];
    for (final record in records) {
      final r = record.recipient;
      final isMe = r.userId == me;
      if (r.permissionStatus == PermissionStatus.rejected && !isCreator && !(isMe && includeRejectedSelf)) {
        continue;
      }
      if (isCreator || isMe) {
        result.add(isMe || record.sharesWithCreator ? r : _masked(r));
      } else if (shareResponses) {
        result.add(record.sharesWithCreator ? r : _masked(r));
      }
    }
    return result;
  }

  static AlarmRecipient _masked(AlarmRecipient r) => AlarmRecipient(
        id: r.id,
        recipientType: r.recipientType,
        recipientId: r.recipientId,
        displayName: r.displayName,
        userId: r.userId,
        sourceGroupId: r.sourceGroupId,
        permissionStatus: r.permissionStatus,
        responseStatus: ResponseStatus.noResponse,
      );

  Alarm _toAlarm(Row row, List<AlarmRecipient> recipients) => Alarm(
        id: row['id'] as String,
        creator: publicUserFromRow(row, 'creator'),
        title: row['title'] as String,
        message: row['message'] as String?,
        localDate: LocalDate.parse(row['local_date'] as String),
        localTime: LocalTime.parse(row['local_time'] as String),
        timezone: row['timezone'] as String,
        scheduledAt: row['scheduled_at'] as DateTime,
        repeat: row['repeat_rule'] == null
            ? null
            : RepeatRule.fromJson(Map<String, dynamic>.from(row['repeat_rule'] as Map)),
        triggerType: TriggerType.fromWire(row['trigger_type'] as String),
        status: AlarmStatus.fromWire(row['status'] as String),
        priority: AlarmPriority.fromWire(row['priority'] as String),
        sound: row['sound'] as String,
        vibration: row['vibration'] as bool,
        shareResponses: row['share_responses'] as bool,
        version: row['version'] as int,
        recipients: recipients,
        nextOccurrenceAt: row['next_occurrence_at'] as DateTime?,
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
        deletedAt: row['deleted_at'] as DateTime?,
        sequenceId: row['sequence_id'] as String?,
        sequenceName: row['sequence_name'] as String?,
        sequencePosition: row['sequence_position'] as int?,
      );

  // ------------------------------------------------------------ respuestas

  static const responseColumns = '''
    x.id::text AS id, o.alarm_id::text AS alarm_id, x.user_id::text AS user_id,
    o.scheduled_for AS occurrence_at, x.response, x.snoozed_until, x.responded_at,
    x.device_id::text AS device_id, x.sync_version
  ''';

  static AlarmResponse responseFromRow(Row r) => AlarmResponse(
        id: r['id'] as String,
        alarmId: r['alarm_id'] as String,
        userId: r['user_id'] as String,
        occurrenceAt: r['occurrence_at'] as DateTime,
        response: ResponseStatus.fromWire(r['response'] as String),
        snoozedUntil: r['snoozed_until'] as DateTime?,
        respondedAt: r['responded_at'] as DateTime,
        deviceId: r['device_id'] as String?,
      );

  /// Respuestas visibles para [me] según las mismas reglas de privacidad.
  Future<List<AlarmResponse>> visibleResponses(String me, {String? alarmId}) async =>
      [for (final r in await _responseRows(me, alarmId: alarmId)) responseFromRow(r)];

  /// Respuestas con cambios desde [cursor] y la mayor versión devuelta.
  Future<(List<AlarmResponse>, int)> responsesSince(String me, int cursor, {int limit = 1000}) async {
    final rows = await _responseRows(me, sinceVersion: cursor, limit: limit);
    final max = rows.isEmpty ? cursor : rows.last['sync_version'] as int;
    return ([for (final r in rows) responseFromRow(r)], max);
  }

  Future<List<Row>> _responseRows(
    String me, {
    String? alarmId,
    int? sinceVersion,
    int limit = 1000,
  }) =>
      db.query(
      '''
      SELECT $responseColumns
      FROM alarm_responses x
      JOIN alarm_occurrences o ON o.id = x.occurrence_id
      JOIN alarms a ON a.id = o.alarm_id
      LEFT JOIN alarm_recipients rr ON rr.alarm_id = a.id AND rr.user_id = x.user_id
        AND rr.recipient_type = 'user'
      LEFT JOIN connection_permissions p
        ON rr.source_group_id IS NULL AND p.owner_id = x.user_id AND p.subject_id = a.creator_id
      WHERE $alarmVisibleSql
        AND (@alarm::uuid IS NULL OR a.id = @alarm::uuid)
        AND (@since::bigint IS NULL OR x.sync_version > @since::bigint)
        AND (
          x.user_id = @me::uuid
          OR (a.creator_id = @me::uuid AND COALESCE(p.share_response_status, true))
          OR (a.share_responses AND COALESCE(p.share_response_status, true))
        )
      ORDER BY x.sync_version
      LIMIT @limit
      ''',
      {'me': me, 'alarm': alarmId, 'since': sinceVersion, 'limit': limit},
      );
}
