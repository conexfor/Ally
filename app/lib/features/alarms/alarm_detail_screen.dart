import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alarm_format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/moment.dart';
import '../profile/devices_screen.dart';

/// Página de la ruta `/alarms/:id`: un bottom sheet que mantiene visible la
/// pantalla anterior (oscurecida y desenfocada).
Page<void> alarmDetailPage(GoRouterState state) => CustomTransitionPage<void>(
      key: state.pageKey,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      child: AlarmDetailScreen(alarmId: state.pathParameters['id']!),
      transitionsBuilder: (_, _, _, child) => child,
    );

class AlarmDetailScreen extends ConsumerWidget {
  final String alarmId;
  const AlarmDetailScreen({super.key, required this.alarmId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final curved = CurvedAnimation(parent: route, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final alarm = ref.watch(alarmProvider(alarmId));
    final meId = ref.watch(meProvider).value?.id ?? '';

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: AnimatedBuilder(
            animation: curved,
            builder: (_, _) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6 * curved.value, sigmaY: 6 * curved.value),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.28 * curved.value)),
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: _SheetFrame(
            child: alarm.when(
              loading: () => const SizedBox(height: 220, child: LoadingView()),
              error: (e, _) => ErrorView(e),
              data: (a) => a == null
                  ? const EmptyState(
                      icon: Icons.alarm_off_rounded,
                      title: 'Este momento ya no está disponible',
                      message: 'Puede que se haya eliminado o que ya no seas parte de él.',
                    )
                  : _Detail(alarm: a, meId: meId),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Superficie del panel con asa de arrastre (deslizar hacia abajo cierra).
class _SheetFrame extends StatelessWidget {
  final Widget child;
  const _SheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 250) Navigator.of(context).maybePop();
            },
            child: SizedBox(
              height: 28,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 20 + media.padding.bottom),
              child: child,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  final Alarm alarm;
  final String meId;
  const _Detail({required this.alarm, required this.meId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(appServicesProvider).alarms;
    final isCreator = alarm.creator.id == meId;
    final mine = alarm.recipientFor(meId);
    final invited = mine?.permissionStatus == PermissionStatus.pending;
    final accepted = mine?.permissionStatus == PermissionStatus.accepted;
    final next = alarm.nextOccurrenceAt;
    final color = momentColor(alarm, meId);
    final status = momentStatus(alarm, meId);
    final people = alarm.recipients
        .where((r) => r.recipientType == RecipientType.user && r.userId != null)
        .toList();
    final groups = alarm.recipients.where((r) => r.recipientType == RecipientType.group).toList();
    final hasMessage = alarm.message?.isNotEmpty == true && alarm.message != alarm.title;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 1. Fecha y proximidad.
      Row(children: [
        Expanded(
          child: Eyebrow(
            next == null ? AlarmFormat.next(alarm) : '${AlarmFormat.day(next)} · ${AlarmFormat.countdown(next).toLowerCase()}',
            color: color,
          ),
        ),
        _MoreMenu(alarm: alarm, isCreator: isCreator),
      ]),
      const SizedBox(height: 6),
      // 2. Hora.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: next == null
            ? BigTime(hour: alarm.localTime.hour, minute: alarm.localTime.minute, size: 64)
            : BigTime.of(next, size: 64),
      ),
      const SizedBox(height: 8),
      // 3. Título.
      Text(alarm.title, style: theme.textTheme.headlineSmall),
      if (hasMessage) ...[
        const SizedBox(height: 6),
        Text(alarm.message!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
      const SizedBox(height: 4),
      Text(
        isCreator ? 'Creado por ti' : 'Creado por ${alarm.creator.displayName}',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      // 4. Personas.
      if (people.isNotEmpty || groups.isNotEmpty) ...[
        const Eyebrow('Personas'),
        const SizedBox(height: 8),
        for (final g in groups)
          _PersonRow(
            avatar: UserAvatar(g.displayName, icon: Icons.groups_rounded, size: 34),
            name: g.displayName,
            trailing: Text('Grupo', style: theme.textTheme.bodySmall),
          ),
        for (final r in people)
          _PersonRow(
            avatar: UserAvatar(r.displayName, size: 34),
            name: r.userId == meId ? '${r.displayName} (tú)' : r.displayName,
            trailing: _ResponseDot(r),
          ),
        const SizedBox(height: 14),
      ],
      // 5. Repetición y 6. estado.
      _InfoLine(icon: Icons.repeat_rounded, label: 'Repetición', value: AlarmFormat.kind(alarm)),
      _InfoLine(icon: Icons.blur_on_rounded, label: 'Estado', child: StatusDot(status.label, color: status.color)),
      if (accepted) _DeviceToggles(alarm: alarm),
      const SizedBox(height: 22),
      // 7. Acciones.
      if (invited)
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainer,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              onPressed: () async {
                final ok = await runGuarded(context, () async {
                  await repo.reject(alarm);
                  return true;
                });
                if (ok != null && context.mounted) {
                  showToast(context, 'Invitación rechazada', icon: Icons.do_not_disturb_on_outlined);
                  Navigator.of(context).maybePop();
                }
              },
              child: const Text('Rechazar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.violet, foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await runGuarded(context, () => repo.accept(alarm));
                if (ok != null && context.mounted) showToast(context, 'Invitación aceptada');
              },
              child: const Text('Aceptar'),
            ),
          ),
        ])
      else if (accepted && next != null) ...[
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainer,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              onPressed: () async {
                final ok = await runGuarded(context, () => repo.respond(alarm, next, ResponseStatus.snoozed));
                if (ok != null && context.mounted) showToast(context, 'Momento pospuesto', icon: Icons.snooze_rounded);
              },
              child: const Text('Posponer'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              onPressed: CompleteButton.isDone(alarm, meId)
                  ? null
                  : () async {
                      if (!await CompleteButton.confirmBeforeRing(context, next) || !context.mounted) return;
                      final ok = await runGuarded(context, () => repo.respond(alarm, next, ResponseStatus.confirmed));
                      if (ok != null && context.mounted) showToast(context, 'Momento confirmado');
                    },
              child: Text(CompleteButton.isDone(alarm, meId) ? 'Confirmado' : 'Confirmar'),
            ),
          ),
        ]),
        const SizedBox(height: 4),
      ],
      if (!invited && next != null && (isCreator || accepted))
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
          onPressed: () async {
            if (isCreator) {
              final ok = await confirmDialog(
                context,
                title: alarm.repeat == null ? 'Cancelar momento' : 'Cancelar la próxima vez',
                message: alarm.repeat == null
                    ? 'No sonará para nadie. Avisaremos a los participantes.'
                    : 'La próxima ocurrencia no sonará para nadie. Las siguientes seguirán igual.',
                confirm: 'Cancelar momento',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              final done = await runGuarded(context, () => repo.cancelNext(alarm));
              if (done != null && context.mounted) showToast(context, 'Momento cancelado', icon: Icons.event_busy_rounded);
            } else {
              final done = await runGuarded(context, () => repo.respond(alarm, next, ResponseStatus.dismissed));
              if (done != null && context.mounted) {
                showToast(context, 'No sonará en tus dispositivos esta vez', icon: Icons.notifications_off_outlined);
              }
            }
          },
          child: Text(isCreator ? 'Cancelar' : 'Omitir esta vez'),
        ),
    ]);
  }
}

class _PersonRow extends StatelessWidget {
  final Widget avatar;
  final String name;
  final Widget trailing;
  const _PersonRow({required this.avatar, required this.name, required this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          trailing,
        ]),
      );
}

class _ResponseDot extends StatelessWidget {
  final AlarmRecipient r;
  const _ResponseDot(this.r);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (r.permissionStatus) {
      PermissionStatus.pending => ('Invitación pendiente', AppTheme.warning),
      PermissionStatus.rejected => ('Rechazó', AppTheme.danger),
      PermissionStatus.accepted => switch (r.responseStatus) {
          ResponseStatus.confirmed => ('Confirmó', AppTheme.green),
          ResponseStatus.snoozed => ('Pospuso', AppTheme.orange),
          ResponseStatus.dismissed => ('Omitió', AppTheme.inkTertiary),
          ResponseStatus.expired => ('Expiró', AppTheme.inkTertiary),
          ResponseStatus.noResponse => ('Por confirmar', AppTheme.inkTertiary),
        },
    };
    return StatusDot(label, color: color);
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;
  const _InfoLine({required this.icon, required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: child ?? Text(value ?? '', style: theme.textTheme.titleSmall, textAlign: TextAlign.end),
          ),
        ),
      ]),
    );
  }
}

/// Editar, eliminar o dejar de recibir: acciones secundarias, fuera de vista.
class _MoreMenu extends ConsumerWidget {
  final Alarm alarm;
  final bool isCreator;
  const _MoreMenu({required this.alarm, required this.isCreator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(appServicesProvider).alarms;
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push('/alarms/${alarm.id}/edit');
          case 'delete':
            final ok = await confirmDialog(
              context,
              title: isCreator ? 'Eliminar momento' : 'Dejar de recibir',
              message: isCreator
                  ? 'Se eliminará para todas las personas.'
                  : 'Este momento dejará de sonar en tus dispositivos.',
              confirm: isCreator ? 'Eliminar' : 'Dejar de recibir',
              destructive: true,
            );
            if (!ok || !context.mounted) return;
            final done = await runGuarded(context, () => repo.delete(alarm));
            if (done != null && context.mounted) {
              showToast(
                context,
                done.queued ? 'Eliminado. Se sincronizará al reconectar.' : 'Momento eliminado',
                icon: Icons.delete_outline_rounded,
              );
              Navigator.of(context).maybePop();
            }
        }
      },
      itemBuilder: (_) => [
        if (isCreator && alarm.isActive) const PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'delete', child: Text(isCreator ? 'Eliminar' : 'Dejar de recibir')),
      ],
    );
  }
}

/// Dónde suena (solo si el usuario tiene varios dispositivos).
class _DeviceToggles extends ConsumerWidget {
  final Alarm alarm;
  const _DeviceToggles({required this.alarm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(myDevicesProvider).value ?? const [];
    final prefs = ref.watch(devicePreferencesProvider).value ?? const {};
    if (devices.length < 2) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Icon(Icons.devices_rounded, size: 18, color: Theme.of(context).colorScheme.outline),
        title: Text('Dónde suena', style: Theme.of(context).textTheme.bodyMedium),
        children: [
          for (final d in devices)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(deviceIcon(d.deviceType)),
              title: Text(d.deviceName),
              value: prefs[alarm.id]?[d.id] ?? d.receivesAlarms,
              onChanged: (v) async {
                await runGuarded(context, () => ref.read(appServicesProvider).alarms.setDeviceEnabled(alarm, d.id, v));
                ref.invalidate(devicePreferencesProvider);
              },
            ),
        ],
      ),
    );
  }
}
