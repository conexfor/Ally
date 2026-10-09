import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import 'alarms_repository.dart';

enum HistoryFilter {
  all('all'),
  created('created'),
  received('received'),
  confirmed('confirmed'),
  snoozed('snoozed'),
  cancelled('cancelled');

  const HistoryFilter(this.wire);
  final String wire;
  static HistoryFilter parse(String? value) =>
      values.firstWhere((f) => f.wire == value, orElse: () => HistoryFilter.all);
}

/// Historial (ocurrencias pasadas) y estadísticas.
class HistoryService {
  final Db db;
  HistoryService(this.db);

  Future<List<HistoryEntry>> history(
    String me, {
    HistoryFilter filter = HistoryFilter.all,
    DateTime? before,
    int limit = 50,
  }) async {
    final filterSql = switch (filter) {
      HistoryFilter.all => '',
      HistoryFilter.created => 'AND a.creator_id = @me::uuid',
      HistoryFilter.received => 'AND a.creator_id <> @me::uuid',
      HistoryFilter.confirmed => "AND mine.response = 'confirmed'",
      HistoryFilter.snoozed => "AND (mine.response = 'snoozed' OR (a.creator_id = @me::uuid AND counts.snoozed > 0))",
      HistoryFilter.cancelled => "AND o.status = 'cancelled'",
    };
    final rows = await db.query(
      '''
      SELECT o.id::text AS occurrence_id, a.id::text AS alarm_id, a.title, o.scheduled_for,
             o.status, a.creator_id = @me::uuid AS is_creator,
             cu.id::text AS creator_id, cu.display_name AS creator_name,
             mine.response AS my_response,
             (SELECT count(*)::int FROM alarm_recipients r
               WHERE r.alarm_id = a.id AND r.recipient_type = 'user' AND r.permission_status = 'accepted') AS recipient_count,
             counts.confirmed, counts.snoozed
      FROM alarm_occurrences o
      JOIN alarms a ON a.id = o.alarm_id
      JOIN users cu ON cu.id = a.creator_id
      LEFT JOIN alarm_responses mine ON mine.occurrence_id = o.id AND mine.user_id = @me::uuid
      CROSS JOIN LATERAL (
        SELECT count(*) FILTER (WHERE x.response = 'confirmed')::int AS confirmed,
               count(*) FILTER (WHERE x.response = 'snoozed')::int AS snoozed
        FROM alarm_responses x WHERE x.occurrence_id = o.id
      ) counts
      WHERE $alarmVisibleSql
        AND o.scheduled_for <= now()
        AND (@before::timestamptz IS NULL OR o.scheduled_for < @before::timestamptz)
        $filterSql
      ORDER BY o.scheduled_for DESC
      LIMIT @limit
      ''',
      {'me': me, 'before': before, 'limit': limit},
    );
    return [
      for (final r in rows)
        HistoryEntry(
          occurrenceId: r['occurrence_id'] as String,
          alarmId: r['alarm_id'] as String,
          title: r['title'] as String,
          occurrenceAt: r['scheduled_for'] as DateTime,
          isCreator: r['is_creator'] as bool,
          creator: PublicUserSummary(
            id: r['creator_id'] as String,
            displayName: r['creator_name'] as String,
          ),
          status: AlarmStatus.fromWire(r['status'] as String),
          myResponse: r['my_response'] == null
              ? null
              : ResponseStatus.fromWire(r['my_response'] as String),
          recipientCount: r['recipient_count'] as int,
          // El creador solo ve los conteos agregados de las respuestas.
          confirmedCount: r['confirmed'] as int,
          snoozedCount: r['snoozed'] as int,
        ),
    ];
  }

  /// Estadísticas del usuario en el periodo (por defecto, el mes actual).
  Future<AlarmStats> stats(String me, {DateTime? since}) async {
    final from = since ?? _startOfMonth();
    final row = await db.one(
      '''
      SELECT
        (SELECT count(*)::int FROM alarms WHERE creator_id = @me::uuid AND created_at >= @from) AS created,
        (SELECT count(*)::int FROM alarm_recipients r JOIN alarms a ON a.id = r.alarm_id
          WHERE r.user_id = @me::uuid AND r.recipient_type = 'user' AND a.creator_id <> @me::uuid
            AND r.created_at >= @from) AS received,
        (SELECT count(*)::int FROM alarm_responses WHERE user_id = @me::uuid AND response = 'confirmed' AND responded_at >= @from) AS confirmed,
        (SELECT count(*)::int FROM alarm_responses WHERE user_id = @me::uuid AND response = 'snoozed' AND responded_at >= @from) AS snoozed,
        (SELECT count(*)::int FROM alarm_responses WHERE user_id = @me::uuid AND response = 'dismissed' AND responded_at >= @from) AS dismissed,
        (SELECT count(*)::int FROM alarms WHERE creator_id = @me::uuid AND status = 'cancelled' AND updated_at >= @from) AS cancelled
      ''',
      {'me': me, 'from': from},
    );
    return AlarmStats.fromJson(row!);
  }

  /// Estadísticas de los grupos activos del usuario en el mes actual.
  Future<List<GroupStats>> groupStats(String me) async {
    final rows = await db.query(
      '''
      SELECT g.id::text AS group_id, g.name AS group_name,
        (SELECT count(*)::int FROM alarm_recipients gr JOIN alarms a ON a.id = gr.alarm_id
          WHERE gr.recipient_type = 'group' AND gr.recipient_id = g.id AND a.created_at >= @from) AS alarms_this_month,
        (SELECT count(*)::int FROM alarm_responses x
          JOIN alarm_occurrences o ON o.id = x.occurrence_id
          JOIN alarm_recipients gr ON gr.alarm_id = o.alarm_id AND gr.recipient_type = 'group' AND gr.recipient_id = g.id
          WHERE x.response = 'confirmed' AND x.responded_at >= @from) AS confirmed,
        (SELECT count(*)::int FROM alarm_responses x
          JOIN alarm_occurrences o ON o.id = x.occurrence_id
          JOIN alarm_recipients gr ON gr.alarm_id = o.alarm_id AND gr.recipient_type = 'group' AND gr.recipient_id = g.id
          WHERE x.response = 'snoozed' AND x.responded_at >= @from) AS snoozed
      FROM groups g JOIN group_members m ON m.group_id = g.id AND m.user_id = @me::uuid AND m.status = 'active'
      WHERE g.deleted_at IS NULL
      ORDER BY g.name
      ''',
      {'me': me, 'from': _startOfMonth()},
    );
    return [for (final r in rows) GroupStats.fromJson(r)];
  }

  static DateTime _startOfMonth() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month);
  }
}
