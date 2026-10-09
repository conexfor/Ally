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
import 'history_screen.dart';

/// Momentos pasados recientes para el historial visual del perfil.
final recentHistoryProvider = FutureProvider.autoDispose<List<HistoryEntry>>(
  (ref) => ref.watch(appServicesProvider).api.history(),
);

/// Categoría visual de un momento pasado.
({String label, Color color}) pastMomentKind(HistoryEntry e) {
  if (e.status == AlarmStatus.cancelled) return (label: 'Canceladas', color: AppTheme.danger);
  return switch (e.myResponse) {
    ResponseStatus.confirmed => (label: 'Confirmadas', color: AppTheme.green),
    ResponseStatus.snoozed => (label: 'Pospuestas', color: AppTheme.orange),
    ResponseStatus.dismissed => (label: 'Rechazadas', color: AppTheme.pink),
    _ => (label: 'Completadas', color: AppTheme.cyan),
  };
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final theme = Theme.of(context);
    final month = ref.watch(monthStatsProvider).value;
    final alarms = ref.watch(alarmsProvider).value ?? const <Alarm>[];
    final shared = alarms
        .where((a) =>
            a.recipients.any((r) => r.recipientType == RecipientType.group) || AlarmFormat.participants(a).length > 1)
        .length;
    final lastSync = ref.watch(lastSyncProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(children: [
              const Expanded(child: Eyebrow('Perfil')),
              IconButton(
                tooltip: 'Configuración',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ]),
            if (me != null)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/profile/edit'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    UserAvatar(me.displayName, size: 64, imageUrl: me.avatarUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(me.displayName, style: theme.textTheme.headlineSmall),
                        Text(me.email ?? '@${me.username}', style: theme.textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: _Metric(
                  value: month == null ? '–' : '${month.created + month.received}',
                  label: 'Momentos este mes',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _Metric(value: '$shared', label: 'Momentos compartidos')),
            ]),
            const SizedBox(height: 24),
            const _HistoryStrip(),
            const SizedBox(height: 24),
            const Eyebrow('Ajustes'),
            const SizedBox(height: 8),
            Surface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                _Item(Icons.history_rounded, 'Historial', onTap: () => context.push('/history')),
                _Item(Icons.people_outline_rounded, 'Personas y grupos', onTap: () => context.push('/people')),
                _Item(Icons.auto_stories_outlined, 'Introducción del producto', onTap: () => context.push('/intro')),
                _Item(Icons.music_note_outlined, 'Sonidos y vibración', onTap: () => context.push('/settings')),
                _Item(Icons.lock_outline_rounded, 'Acceso y cuenta', onTap: () => context.push('/profile/edit')),
                _Item(Icons.devices_rounded, 'Dispositivos', onTap: () => context.push('/devices')),
                _Item(Icons.notifications_none_rounded, 'Notificaciones', onTap: () => context.push('/notifications')),
                _Item(
                  Icons.sync_rounded,
                  'Sincronizar ahora',
                  subtitle: lastSync == null
                      ? 'Aún no se ha sincronizado'
                      : 'Última vez: ${AlarmFormat.day(lastSync).toLowerCase()}, ${AlarmFormat.time(lastSync)}',
                  onTap: () async {
                    final result = await ref.read(sessionProvider.notifier).syncNow();
                    if (!context.mounted) return;
                    result.success
                        ? showToast(context, 'Todo al día', icon: Icons.cloud_done_outlined)
                        : showMessage(context, 'Sin conexión. Se reintentará más tarde.');
                  },
                  last: true,
                ),
              ]),
            ),
            const SizedBox(height: 20),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Cerrar sesión',
                  message: 'Las alarmas dejarán de sonar en este dispositivo hasta que vuelvas a entrar.',
                  confirm: 'Cerrar sesión',
                );
                if (ok) await ref.read(sessionProvider.notifier).logout();
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Surface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: AppTheme.time(34, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

/// Historial visual: una secuencia de pequeños círculos, uno por momento.
class _HistoryStrip extends ConsumerWidget {
  const _HistoryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(recentHistoryProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/history'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Eyebrow('Tu historial')),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
        ]),
        const SizedBox(height: 10),
        history.when(
          loading: () => const SizedBox(height: 40),
          error: (_, _) => Text('No se pudo cargar el historial.', style: theme.textTheme.bodySmall),
          data: (entries) {
            if (entries.isEmpty) {
              return Text('Tus momentos pasados aparecerán aquí.', style: theme.textTheme.bodySmall);
            }
            final recent = entries.take(28).toList().reversed.toList();
            final kinds = {for (final e in recent) pastMomentKind(e).label: pastMomentKind(e).color};
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                label: '${recent.length} momentos recientes',
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (i, e) in recent.indexed)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 200 + i * 18),
                      curve: Curves.easeOutBack,
                      builder: (_, t, child) => Transform.scale(scale: t, child: child),
                      child: Tooltip(
                        message: '${e.title} · ${AlarmFormat.shortDate(e.occurrenceAt)}',
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: pastMomentKind(e).color, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 6, children: [
                for (final k in kinds.entries) StatusDot(k.key, color: k.value, fontSize: 11),
              ]),
            ]);
          },
        ),
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool last;
  const _Item(this.icon, this.title, {required this.onTap, this.subtitle, this.last = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          leading: Icon(icon, size: 22),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
          onTap: onTap,
        ),
        if (!last) const Divider(indent: 56, endIndent: 16),
      ]);
}
