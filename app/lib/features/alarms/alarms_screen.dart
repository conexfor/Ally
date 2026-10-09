import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../application/session_controller.dart';
import '../../core/utils/alarm_format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/moment.dart';
import '../../core/widgets/ui.dart';

enum _Filter {
  all('Todas'),
  upcoming('Próximas'),
  recurring('Recurrentes'),
  invited('De otros');

  const _Filter(this.label);
  final String label;

  bool matches(Alarm a, String meId) {
    if (!a.isActive || a.nextOccurrenceAt == null) return false;
    return switch (this) {
      _Filter.all => true,
      // Próximos 7 días.
      _Filter.upcoming => a.nextOccurrenceAt!.isBefore(DateTime.now().toUtc().add(const Duration(days: 7))),
      _Filter.recurring => a.repeat != null,
      _Filter.invited => a.creator.id != meId,
    };
  }
}

/// Alarmas en las que participo: las que creé y las de otras personas a las
/// que estoy invitado (las rechazadas no cuentan).
bool _involves(Alarm a, String meId) {
  if (a.creator.id == meId) return true;
  final status = a.recipientFor(meId)?.permissionStatus;
  return status != null && status != PermissionStatus.rejected;
}

/// Mis alarmas (propias y en las que participo): gestión sin aspecto de tabla.
class AlarmsScreen extends ConsumerStatefulWidget {
  const AlarmsScreen({super.key});

  @override
  ConsumerState<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends ConsumerState<AlarmsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
    if (_searching) _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meId = ref.watch(meProvider).value?.id ?? '';
    final alarms = ref.watch(alarmsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(sessionProvider.notifier).syncNow(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Tu tiempo'),
                        const SizedBox(height: 6),
                        Text('Mis alarmas', style: theme.textTheme.headlineMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rutinas',
                    icon: const Icon(Icons.linear_scale_rounded),
                    onPressed: () => context.push('/sequences'),
                  ),
                  IconButton.outlined(
                    tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar',
                    style: IconButton.styleFrom(side: BorderSide(color: theme.colorScheme.outlineVariant)),
                    icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                    onPressed: _toggleSearch,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _searching
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextField(
                          controller: _search,
                          focusNode: _searchFocus,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Buscar momentos o personas',
                            prefixIcon: Icon(Icons.search_rounded),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AsyncBody(
                value: alarms,
                builder: (list) {
                  final query = TextNormalizer.nameKey(_search.text);
                  final mine =
                      list
                          .where((a) => _involves(a, meId) && _filter.matches(a, meId))
                          .where((a) => query.isEmpty || _haystack(a).contains(query))
                          .toList()
                        ..sort((a, b) => a.nextOccurrenceAt!.compareTo(b.nextOccurrenceAt!));
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey('$_filter|$query|${mine.length}'),
                      child: mine.isEmpty
                          ? _Empty(searching: query.isNotEmpty)
                          : Column(
                              children: [
                                for (final (i, a) in mine.indexed)
                                  // Variación ligera de alineación entre tarjetas.
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: i.isOdd ? 14 : 0,
                                      right: i.isOdd ? 0 : 14,
                                      bottom: 12,
                                    ),
                                    child: MomentCard(alarm: a, meId: meId),
                                  ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _haystack(Alarm a) =>
      TextNormalizer.nameKey([a.title, a.message ?? '', for (final r in a.recipients) r.displayName].join(' '));
}

class _Empty extends StatelessWidget {
  final bool searching;
  const _Empty({required this.searching});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(searching ? 'Sin coincidencias' : 'Nada por aquí', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            searching ? 'Prueba con otra palabra.' : 'Crea un momento y aparecerá en tu tiempo.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (!searching) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: () => context.go('/assistant'), child: const Text('Crear momento')),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de un momento: color de identidad, hora, título, contexto,
/// participantes, estado y acción de completar.
class MomentCard extends StatelessWidget {
  final Alarm alarm;
  final String meId;
  const MomentCard({super.key, required this.alarm, required this.meId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = momentColor(alarm, meId);
    final next = alarm.nextOccurrenceAt ?? alarm.scheduledAt;
    final people = AlarmFormat.participants(alarm);
    final status = momentStatus(alarm, meId);
    return Surface(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/alarms/${alarm.id}'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3.5,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Eyebrow(AlarmFormat.day(next), color: color),
                        if (alarm.repeat != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.repeat_rounded, size: 13, color: theme.colorScheme.outline),
                        ],
                        const Spacer(),
                        StatusDot(status.label, color: status.color, fontSize: 11.5),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BigTime.of(next, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                alarm.title,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                alarm.repeat != null ? AlarmFormat.kind(alarm) : AlarmFormat.audience(alarm, meId),
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (people.length > 1) ...[AvatarStack(people, size: 24, max: 3), const SizedBox(width: 10)],
                        if (CompleteButton.canComplete(alarm, meId))
                          CompleteButton(alarm: alarm, meId: meId, color: color, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
