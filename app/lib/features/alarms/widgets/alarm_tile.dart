import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../../core/utils/alarm_format.dart';
import '../../../core/widgets/common.dart';

/// Fila de alarma usada en Inicio y en los listados.
class AlarmTile extends StatelessWidget {
  final Alarm alarm;
  final String meId;
  final bool compact;

  const AlarmTile({super.key, required this.alarm, required this.meId, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = alarm.nextOccurrenceAt;
    final pendingForMe = alarm.recipientFor(meId)?.permissionStatus == PermissionStatus.pending;
    final confirmations = AlarmFormat.confirmations(alarm, meId);
    final repeat = AlarmFormat.repeat(alarm);
    final routine = alarm.sequenceName == null
        ? null
        : 'Rutina «${alarm.sequenceName}» · paso ${(alarm.sequencePosition ?? 0) + 1}';

    return AppCard(
      onTap: () => context.push('/alarms/${alarm.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next == null ? SpanishFormatter.time(alarm.localTime) : AlarmFormat.time(next),
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, letterSpacing: -0.4),
                ),
                if (!compact && next != null)
                  Text(AlarmFormat.day(next), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(alarm.title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  PriorityChip(alarm.priority),
                ]),
                const SizedBox(height: 3),
                Text(
                  [?routine, AlarmFormat.audience(alarm, meId), ?repeat, ?confirmations].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (pendingForMe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Aceptar', style: TextStyle(color: theme.colorScheme.onTertiaryContainer, fontWeight: FontWeight.w700, fontSize: 12)),
            )
          else
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}
