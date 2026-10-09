import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';

final sequencesProvider = FutureProvider<List<AlarmSequence>>(
  (ref) => ref.watch(appServicesProvider).alarms.sequences(),
);

/// Rutinas: alarmas encadenadas que se crean y eliminan juntas.
class SequencesScreen extends ConsumerWidget {
  const SequencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sequences = ref.watch(sequencesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Rutinas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/sequences/new');
          ref.invalidate(sequencesProvider);
        },
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('Nueva rutina'),
      ),
      body: AsyncBody(
        value: sequences,
        onRetry: () => ref.invalidate(sequencesProvider),
        builder: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.linear_scale_rounded,
                title: 'Sin rutinas',
                message: 'Encadena alarmas: 07:00 Despertar → 07:15 Prepararse → 07:30 Salir de casa.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(sequencesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(s.name, style: theme.textTheme.titleLarge)),
                          IconButton(
                            tooltip: 'Eliminar rutina',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final ok = await confirmDialog(
                                context,
                                title: 'Eliminar rutina',
                                message: 'Se eliminarán sus ${s.steps.length} alarmas para todos los destinatarios.',
                                confirm: 'Eliminar',
                                destructive: true,
                              );
                              if (!ok || !context.mounted) return;
                              await runGuarded(
                                context,
                                () => ref.read(appServicesProvider).alarms.deleteSequence(s),
                                success: 'Rutina eliminada.',
                              );
                              ref.invalidate(sequencesProvider);
                            },
                          ),
                        ]),
                        const SizedBox(height: 8),
                        for (final (index, step) in s.steps.indexed)
                          _StepRow(
                            time: SpanishFormatter.time(step.localTime),
                            title: step.title,
                            isLast: index == s.steps.length - 1,
                            onTap: () => context.push('/alarms/${step.alarmId}'),
                          ),
                      ]),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// Paso con línea de tiempo vertical.
class _StepRow extends StatelessWidget {
  final String time;
  final String title;
  final bool isLast;
  final VoidCallback onTap;

  const _StepRow({required this.time, required this.title, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 20,
            child: Column(children: [
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: scheme.primary.withValues(alpha: 0.3))),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                SizedBox(width: 84, child: Text(time, style: Theme.of(context).textTheme.titleSmall)),
                Expanded(child: Text(title)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
