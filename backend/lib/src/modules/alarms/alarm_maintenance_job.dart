import 'dart:async';

import 'package:logging/logging.dart';
import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';

/// Tarea periódica que mantiene el estado del servidor al día:
///
/// - registra en `alarm_occurrences` cada ocurrencia que llegó a su hora
///   (base del historial);
/// - avanza `next_occurrence_at` de las alarmas recurrentes y marca como
///   completadas las que ya no volverán a sonar.
///
/// No hace sonar nada: las alarmas suenan en los dispositivos, que las tienen
/// programadas localmente.
class AlarmMaintenanceJob {
  final Db db;
  final Duration interval;
  final _log = Logger('AlarmMaintenanceJob');
  Timer? _timer;
  bool _running = false;

  AlarmMaintenanceJob(this.db, {this.interval = const Duration(minutes: 1)});

  void start() {
    _timer ??= Timer.periodic(interval, (_) => runOnce());
    unawaited(runOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Procesa las alarmas vencidas. Devuelve cuántas se actualizaron.
  Future<int> runOnce({DateTime? now}) async {
    if (_running) return 0;
    _running = true;
    var processed = 0;
    try {
      final current = now ?? DateTime.now().toUtc();
      final rows = await db.query(
        '''
        SELECT id::text AS id, local_date::text AS local_date, to_char(local_time, 'HH24:MI') AS local_time,
               timezone, repeat_rule, next_occurrence_at
        FROM alarms
        WHERE deleted_at IS NULL AND status IN ('scheduled', 'triggered', 'snoozed')
          AND next_occurrence_at <= @now
        ORDER BY next_occurrence_at
        LIMIT 500
        ''',
        {'now': current},
      );
      for (final row in rows) {
        final start = LocalDateTime(
          LocalDate.parse(row['local_date'] as String),
          LocalTime.parse(row['local_time'] as String),
        );
        final rule = row['repeat_rule'] == null
            ? null
            : RepeatRule.fromJson(Map<String, dynamic>.from(row['repeat_rule'] as Map));
        final due = row['next_occurrence_at'] as DateTime;
        final next = ZonedSchedule.nextOccurrenceUtc(
          start: start,
          rule: rule,
          timezone: row['timezone'] as String,
          afterUtc: current,
        );
        await db.transaction((tx) async {
          await tx.execute(
            "INSERT INTO alarm_occurrences (alarm_id, scheduled_for, status) VALUES (@id::uuid, @at, 'triggered') "
            'ON CONFLICT (alarm_id, scheduled_for) DO NOTHING',
            {'id': row['id'], 'at': due},
          );
          await tx.execute(
            'UPDATE alarms SET next_occurrence_at = @next, '
            "status = CASE WHEN @next::timestamptz IS NULL THEN 'completed' ELSE 'scheduled' END "
            'WHERE id = @id::uuid',
            {'id': row['id'], 'next': next},
          );
          if (rule != null && next != null) {
            // El resumen de respuestas se refiere a la ocurrencia en curso.
            await tx.execute(
              "UPDATE alarm_recipients SET response_status = 'no_response', responded_at = NULL "
              "WHERE alarm_id = @id::uuid AND response_status <> 'no_response' AND responded_at < @due",
              {'id': row['id'], 'due': due},
            );
          }
        });
        processed++;
      }
    } catch (e, st) {
      _log.warning('Fallo en el mantenimiento de alarmas', e, st);
    } finally {
      _running = false;
    }
    return processed;
  }
}
