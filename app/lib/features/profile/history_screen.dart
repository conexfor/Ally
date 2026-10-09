import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alarm_format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/ui.dart';

const _filters = {
  'all': 'Todas',
  'created': 'Enviadas',
  'received': 'Recibidas',
  'confirmed': 'Confirmadas',
  'snoozed': 'Pospuestas',
  'cancelled': 'Canceladas',
};

/// Totales del mes en curso para el resumen del historial.
final monthStatsProvider = FutureProvider.autoDispose<AlarmStats>(
  (ref) async => (await ref.watch(appServicesProvider).api.stats(allTime: false)).$1,
);

/// Historial cronológico de actividad con resumen mensual.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _pageSize = 50;
  String _filter = 'all';
  final _entries = <HistoryEntry>[];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _entries.clear();
      _hasMore = true;
      _error = null;
    });
    ref.invalidate(monthStatsProvider);
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final filter = _filter;
    try {
      final page = await ref.read(appServicesProvider).api.history(
            filter: filter,
            before: _entries.isEmpty ? null : _entries.last.occurrenceAt,
          );
      if (!mounted || filter != _filter) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length >= _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _MonthSummary(stats: ref.watch(monthStatsProvider));
    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final e in _filters.entries)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: _filter == e.key,
              onSelected: (_) {
                _filter = e.key;
                _reload();
              },
            ),
          ),
      ]),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Estadísticas',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push('/stats'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              PageBody(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  LayoutBuilder(builder: (context, c) {
                    if (c.maxWidth >= 900) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          flex: 3,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            filters,
                            const SizedBox(height: 8),
                            _timeline(),
                          ]),
                        ),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: summary),
                      ]);
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      summary,
                      const SizedBox(height: 20),
                      filters,
                      const SizedBox(height: 8),
                      _timeline(),
                    ]);
                  }),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeline() {
    if (_entries.isEmpty) {
      if (_error != null) return ErrorView(_error!, onRetry: _reload);
      if (_loading) return const Padding(padding: EdgeInsets.all(40), child: LoadingView());
      return const EmptyState(
        icon: Icons.history_toggle_off_rounded,
        title: 'Sin actividad',
        message: 'Aquí verás las alarmas que ya sonaron y cómo respondieron.',
      );
    }
    final byDay = <String, List<HistoryEntry>>{};
    for (final e in _entries) {
      byDay.putIfAbsent(AlarmFormat.day(e.occurrenceAt), () => []).add(e);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final day in byDay.entries) ...[
        SectionHeader(day.key),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (final (i, e) in day.value.indexed)
              _EventRow(entry: e, first: i == 0, last: i == day.value.length - 1),
          ]),
        ),
      ],
      if (_hasMore)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : OutlinedButton(onPressed: _loadMore, child: const Text('Cargar más')),
        ),
    ]);
  }
}

typedef _Event = ({String label, String detail, Color color, IconData icon});

_Event _eventOf(HistoryEntry e, ColorScheme scheme) {
  if (e.status == AlarmStatus.cancelled) {
    return (label: 'Cancelación', detail: 'La alarma se canceló', color: AppTheme.danger, icon: Icons.event_busy_rounded);
  }
  if (e.isCreator && e.recipientCount > 1) {
    return (
      label: 'Envío',
      detail: 'Enviada a ${e.recipientCount} personas · ${e.confirmedCount} confirmaron',
      color: scheme.primary,
      icon: Icons.send_rounded,
    );
  }
  final from = e.isCreator ? '' : ' · de ${e.creator.displayName}';
  return switch (e.myResponse) {
    ResponseStatus.confirmed =>
      (label: 'Confirmación', detail: 'Confirmaste$from', color: AppTheme.success, icon: Icons.check_circle_rounded),
    ResponseStatus.snoozed =>
      (label: 'Posposición', detail: 'Pospusiste$from', color: AppTheme.warning, icon: Icons.snooze_rounded),
    ResponseStatus.dismissed =>
      (label: 'Descartada', detail: 'La omitiste$from', color: scheme.outline, icon: Icons.notifications_off_rounded),
    _ => (label: 'Completada', detail: 'Sonó sin respuesta$from', color: scheme.outline, icon: Icons.done_all_rounded),
  };
}

class _EventRow extends StatelessWidget {
  final HistoryEntry entry;
  final bool first;
  final bool last;
  const _EventRow({required this.entry, required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = _eventOf(entry, theme.colorScheme);
    final line = theme.colorScheme.outlineVariant;
    return InkWell(
      onTap: () => context.push('/alarms/${entry.alarmId}'),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Column(children: [
              Container(width: 2, height: 10, color: first ? Colors.transparent : line),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: event.color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(event.icon, size: 18, color: event.color),
              ),
              Expanded(child: Container(width: 2, color: last ? Colors.transparent : line)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(entry.title,
                        style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(AlarmFormat.time(entry.occurrenceAt), style: theme.textTheme.bodySmall),
                ]),
                const SizedBox(height: 2),
                Text(
                  '${event.label} · ${event.detail}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(AlarmFormat.shortDate(entry.occurrenceAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Gráfica circular del mes: confirmadas, pospuestas y canceladas.
class _MonthSummary extends StatelessWidget {
  final AsyncValue<AlarmStats> stats;
  const _MonthSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlockCard(
      title: 'Resumen del mes',
      icon: Icons.donut_large_rounded,
      child: stats.when(
        loading: () => const SizedBox(height: 180, child: LoadingView()),
        error: (_, _) => Text('No se pudo cargar el resumen.', style: theme.textTheme.bodyMedium),
        data: (s) {
          final slices = [
            (label: 'Confirmadas', value: s.confirmed, color: AppTheme.success, icon: Icons.check_circle_rounded),
            (label: 'Pospuestas', value: s.snoozed, color: AppTheme.warning, icon: Icons.snooze_rounded),
            (label: 'Canceladas', value: s.cancelled, color: AppTheme.danger, icon: Icons.event_busy_rounded),
          ];
          final total = slices.fold<int>(0, (sum, x) => sum + x.value);
          String percent(int v) => total == 0 ? '0 %' : '${(v * 100 / total).round()} %';
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Semantics(
                label: [for (final x in slices) '${x.label}: ${x.value}'].join(', '),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      values: [for (final x in slices) x.value],
                      colors: [for (final x in slices) x.color],
                      track: theme.colorScheme.surfaceContainerHighest,
                      gap: theme.cardTheme.color ?? theme.colorScheme.surface,
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$total', style: theme.textTheme.headlineMedium),
                        Text('respuestas', style: theme.textTheme.bodySmall),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (final x in slices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(x.icon, size: 18, color: x.color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(x.label, style: theme.textTheme.bodyMedium)),
                  Text('${x.value}', style: theme.textTheme.titleMedium),
                  SizedBox(
                    width: 56,
                    child: Text(percent(x.value),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final Color track;
  final Color gap;

  _DonutPainter({required this.values, required this.colors, required this.track, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = values.fold<int>(0, (a, b) => a + b);
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (total == 0) return;
    final visible = [for (final (i, v) in values.indexed) if (v > 0) i];
    // Separación de 2 px entre segmentos (convertida a ángulo).
    final gapAngle = visible.length > 1 ? 2 / rect.width * 2 : 0.0;
    var start = -math.pi / 2;
    for (final i in visible) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(rect, start + gapAngle / 2, math.max(sweep - gapAngle, 0.01), false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values.toString() != values.toString() || old.track != track || old.gap != gap;
}
