import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import 'response_bar.dart';

final statsAllTimeProvider = StateProvider<bool>((ref) => false);

final statsProvider = FutureProvider<(AlarmStats, List<GroupStats>)>((ref) {
  final allTime = ref.watch(statsAllTimeProvider);
  return ref.watch(appServicesProvider).api.stats(allTime: allTime);
});

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTime = ref.watch(statsAllTimeProvider);
    final stats = ref.watch(statsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: AsyncBody(
        value: stats,
        onRetry: () => ref.invalidate(statsProvider),
        builder: (data) {
          final (user, groups) = data;
          final tiles = [
            ('Creadas', user.created, Icons.add_alarm_rounded, scheme.primary),
            ('Recibidas', user.received, Icons.inbox_rounded, scheme.tertiary),
            ('Confirmadas', user.confirmed, Icons.check_circle_rounded, AppTheme.success),
            ('Pospuestas', user.snoozed, Icons.snooze_rounded, AppTheme.warning),
            ('Descartadas', user.dismissed, Icons.notifications_off_rounded, scheme.outline),
            ('Canceladas', user.cancelled, Icons.event_busy_rounded, AppTheme.danger),
          ];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Este mes')),
                  ButtonSegment(value: true, label: Text('Siempre')),
                ],
                selected: {allTime},
                onSelectionChanged: (s) => ref.read(statsAllTimeProvider.notifier).state = s.first,
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  for (final (label, value, icon, color) in tiles)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(icon, color: color),
                          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
                          Text(label, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
              const SectionHeader('Cómo respondiste'),
              AppCard(
                child: ResponseBar(shares: [
                  ResponseShare('Confirmadas', user.confirmed, AppTheme.success, Icons.check_circle_rounded),
                  ResponseShare('Pospuestas', user.snoozed, AppTheme.warning, Icons.snooze_rounded),
                  ResponseShare('Descartadas', user.dismissed, scheme.outline, Icons.notifications_off_rounded),
                ]),
              ),
              if (groups.isNotEmpty) ...[
                const SectionHeader('Grupos (este mes)'),
                for (final g in groups) ...[
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(g.groupName, style: Theme.of(context).textTheme.titleMedium)),
                        Text('${g.alarmsThisMonth} alarmas', style: Theme.of(context).textTheme.bodyMedium),
                      ]),
                      const SizedBox(height: 12),
                      ResponseBar(shares: [
                        ResponseShare('Confirmadas', g.confirmed, AppTheme.success, Icons.check_circle_rounded),
                        ResponseShare('Pospuestas', g.snoozed, AppTheme.warning, Icons.snooze_rounded),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
