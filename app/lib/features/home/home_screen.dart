import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../application/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alarm_format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/moment.dart';
import '../../core/widgets/ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final alarms = ref.watch(alarmsProvider);
    final issues = ref.watch(syncIssuesProvider).value ?? const <String>[];
    final pendingOutbox = ref.watch(pendingOutboxProvider).value ?? 0;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final firstName = me?.displayName.split(' ').first ?? '';
    final meId = me?.id ?? '';
    final invitations = (alarms.value ?? const <Alarm>[])
        .where((a) => a.recipientFor(meId)?.permissionStatus == PermissionStatus.pending)
        .length;

    final notices = <Widget>[
      if (me != null && me.email != null && !me.emailVerified)
        _Notice(
          icon: Icons.mark_email_unread_outlined,
          text: 'Confirma tu correo. Toca para reenviar el enlace.',
          onTap: () => runGuarded(context, () => ref.read(appServicesProvider).auth.resendVerification())
              .then((message) {
            if (message != null && context.mounted) showMessage(context, message);
          }),
        ),
      if (invitations > 0)
        _Notice(
          icon: Icons.mail_outline_rounded,
          text: invitations == 1 ? 'Tienes 1 invitación pendiente' : 'Tienes $invitations invitaciones pendientes',
          color: AppTheme.violet,
          onTap: () => context.go('/received'),
        ),
      if (pendingOutbox > 0)
        const _Notice(icon: Icons.cloud_upload_outlined, text: 'Cambios sin enviar. Se sincronizarán al reconectar.'),
      for (final issue in issues)
        _Notice(
          icon: Icons.sync_problem_rounded,
          text: issue,
          onTap: () => ref.read(appServicesProvider).store.clearSyncIssues(),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(sessionProvider.notifier).syncNow(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _DateTag(DateTime.now()),
                    const SizedBox(height: 10),
                    Text(
                      '${AlarmFormat.greeting(DateTime.now())}${firstName.isEmpty ? '' : ', $firstName'}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    backgroundColor: AppTheme.violet,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                if (me != null)
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: UserAvatar(me.displayName, size: 40, imageUrl: me.avatarUrl),
                  ),
              ]),
              SizedBox(height: isShortScreen(context) ? 16 : 24),
              AsyncBody(
                value: alarms,
                builder: (list) {
                  final upcoming = _upcoming(list, meId);
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _NowBlock(upcomingToday: upcoming.where(_isToday).length),
                    for (final n in notices) ...[const SizedBox(height: 10), n],
                    SizedBox(height: isShortScreen(context) ? 18 : 26),
                    _DayTimeline(upcoming: upcoming, meId: meId),
                    const SizedBox(height: 22),
                    _Coordination(upcoming: upcoming, meId: meId),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Alarm> _upcoming(List<Alarm> alarms, String meId) {
    final now = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    return alarms
        .where((a) =>
            a.isActive &&
            a.nextOccurrenceAt != null &&
            a.nextOccurrenceAt!.isAfter(now) &&
            a.recipientFor(meId)?.permissionStatus != PermissionStatus.pending)
        .toList()
      ..sort((a, b) => a.nextOccurrenceAt!.compareTo(b.nextOccurrenceAt!));
  }
}

bool _isToday(Alarm a) => LocalDate.fromDateTime(a.nextOccurrenceAt!.toLocal()) == AlarmFormat.today;

class _DateTag extends StatelessWidget {
  final DateTime date;
  const _DateTag(this.date);

  @override
  Widget build(BuildContext context) {
    final label = AlarmFormat.longDate(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Eyebrow(label),
    );
  }
}

/// Hora actual con un pequeño bloque contextual.
class _NowBlock extends StatefulWidget {
  final int upcomingToday;
  const _NowBlock({required this.upcomingToday});

  @override
  State<_NowBlock> createState() => _NowBlockState();
}

class _NowBlockState extends State<_NowBlock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Se actualiza justo al cambiar el minuto.
  void _schedule() {
    final now = DateTime.now();
    _timer = Timer(Duration(seconds: 60 - now.second), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _mood => switch (widget.upcomingToday) {
        0 => 'Un día en calma',
        1 || 2 => 'Un día con buen ritmo',
        _ => 'Un día intenso',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      BigTime(hour: _now.hour, minute: _now.minute, size: isShortScreen(context) ? 58 : 72),
      const SizedBox(width: 16),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              _Pulse(color: AppTheme.cyan),
              SizedBox(width: 6),
              Eyebrow('Ahora', color: AppTheme.cyan),
            ]),
            const SizedBox(height: 4),
            Text(_mood, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    ]);
  }
}

/// Punto que late suavemente (indica el presente).
class _Pulse extends StatefulWidget {
  final Color color;
  const _Pulse({required this.color});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
        child: Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

/// Línea temporal vertical del día.
class _DayTimeline extends StatelessWidget {
  final List<Alarm> upcoming;
  final String meId;
  const _DayTimeline({required this.upcoming, required this.meId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = upcoming.where(_isToday).toList();
    // Sin momentos hoy: se muestran los próximos días.
    final items = today.isNotEmpty ? today : upcoming.take(4).toList();
    final title = today.isNotEmpty ? 'Tu día' : 'Próximos momentos';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Eyebrow(title),
        const Spacer(),
        if (upcoming.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => context.go('/alarms'),
            child: const Text('Ver todas'),
          ),
      ]),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Surface(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text('No tienes momentos por delante. Toca + para crear uno.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ]),
        )
      else ...[
        _TimelineRow(
          time: 'Ahora',
          node: AppTheme.cyan,
          first: true,
          last: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _dayProgress(),
                minHeight: 3,
                color: AppTheme.cyan,
                backgroundColor: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        for (final (i, a) in items.indexed)
          _TimelineRow(
            time: AlarmFormat.time(a.nextOccurrenceAt!).replaceAll(' ', '\n'),
            node: momentColor(a, meId),
            first: false,
            last: i == items.length - 1,
            emphasized: i == 0,
            child: i == 0 ? _NextMoment(alarm: a, meId: meId) : _LaterMoment(alarm: a, meId: meId, showDay: today.isEmpty),
          ),
      ],
    ]);
  }

  static double _dayProgress() {
    final now = DateTime.now();
    return (now.hour * 60 + now.minute) / (24 * 60);
  }
}

class _TimelineRow extends StatelessWidget {
  final String time;
  final Color node;
  final bool first;
  final bool last;
  final bool emphasized;
  final Widget child;

  const _TimelineRow({
    required this.time,
    required this.node,
    required this.first,
    required this.last,
    required this.child,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axis = theme.colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 46,
          child: Padding(
            padding: EdgeInsets.only(top: emphasized ? 18 : 2),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: emphasized ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 22,
          child: Column(children: [
            Container(width: 1.2, height: emphasized ? 20 : 4, color: first ? Colors.transparent : axis),
            Container(
              width: emphasized ? 12 : 9,
              height: emphasized ? 12 : 9,
              decoration: BoxDecoration(
                color: node,
                shape: BoxShape.circle,
                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                boxShadow: [BoxShadow(color: node.withValues(alpha: 0.35), blurRadius: emphasized ? 8 : 0)],
              ),
            ),
            Expanded(child: Container(width: 1.2, color: last ? Colors.transparent : axis)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ]),
    );
  }
}

/// La próxima alarma: tarjeta expandida integrada en la línea temporal.
class _NextMoment extends StatelessWidget {
  final Alarm alarm;
  final String meId;
  const _NextMoment({required this.alarm, required this.meId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = alarm.nextOccurrenceAt!;
    final color = momentColor(alarm, meId);
    final people = AlarmFormat.participants(alarm);
    final status = momentStatus(alarm, meId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Surface(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/alarms/${alarm.id}'),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Eyebrow('Siguiente', color: color),
                    const Spacer(),
                    CountdownText(
                      next,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: BigTime.of(next, size: 44),
                  ),
                  const SizedBox(height: 6),
                  Text(alarm.title, style: theme.textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (!_isToday(alarm))
                    Text(AlarmFormat.day(next), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 14),
                  Row(children: [
                    if (people.isNotEmpty) ...[
                      AvatarStack(people, size: 26, max: 3),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: StatusDot(status.label, color: status.color)),
                    if (CompleteButton.canComplete(alarm, meId)) CompleteButton(alarm: alarm, meId: meId, color: color),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Momentos posteriores: presentación más ligera.
class _LaterMoment extends StatelessWidget {
  final Alarm alarm;
  final String meId;
  final bool showDay;
  const _LaterMoment({required this.alarm, required this.meId, required this.showDay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final people = AlarmFormat.participants(alarm);
    final context_ = [
      if (showDay) AlarmFormat.day(alarm.nextOccurrenceAt!),
      if (alarm.repeat != null) AlarmFormat.kind(alarm) else AlarmFormat.audience(alarm, meId),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/alarms/${alarm.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(alarm.title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(context_, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (people.length > 1) ...[AvatarStack(people, size: 22, max: 3), const SizedBox(width: 6)],
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
          ]),
        ),
      ),
    );
  }
}

/// Mensaje final de tranquilidad (no es una tarjeta analítica).
class _Coordination extends StatelessWidget {
  final List<Alarm> upcoming;
  final String meId;
  const _Coordination({required this.upcoming, required this.meId});

  @override
  Widget build(BuildContext context) {
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final waiting = upcoming.where((a) => awaitingConfirmation(a, meId)).length;
    final ok = waiting == 0;
    final color = ok ? AppTheme.green : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(ok ? Icons.done_all_rounded : Icons.hourglass_top_rounded, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ok ? 'Todo coordinado' : 'Esperando respuestas', style: theme.textTheme.titleSmall),
            Text(
              ok
                  ? 'Tus próximos momentos están confirmados.'
                  : waiting == 1
                      ? 'Un momento espera confirmación.'
                      : '$waiting momentos esperan confirmación.',
              style: theme.textTheme.bodySmall,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  const _Notice({required this.icon, required this.text, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.onSurfaceVariant;
    return Surface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      child: Row(children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        if (onTap != null) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
      ]),
    );
  }
}
