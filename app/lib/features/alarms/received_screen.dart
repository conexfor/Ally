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

/// Alarmas creadas por otras personas: invitaciones y momentos aceptados.
class ReceivedScreen extends ConsumerStatefulWidget {
  const ReceivedScreen({super.key});

  @override
  ConsumerState<ReceivedScreen> createState() => _ReceivedScreenState();
}

class _ReceivedScreenState extends ConsumerState<ReceivedScreen> {
  /// Invitaciones respondidas: desaparecen al instante, sin esperar a la
  /// sincronización.
  final _answered = <String>{};

  Future<void> _answer(Alarm alarm, {required bool accept}) async {
    setState(() => _answered.add(alarm.id));
    final repo = ref.read(appServicesProvider).alarms;
    final ok = await runGuarded(context, () async {
      accept ? await repo.accept(alarm) : await repo.reject(alarm);
      return true;
    });
    if (!mounted) return;
    if (ok == null) {
      setState(() => _answered.remove(alarm.id));
    } else {
      showToast(
        context,
        accept ? 'Invitación aceptada' : 'Invitación rechazada',
        icon: accept ? Icons.check_circle_rounded : Icons.do_not_disturb_on_outlined,
      );
    }
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
              const Eyebrow('De otras personas'),
              const SizedBox(height: 6),
              Text('Recibidas', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 20),
              AsyncBody(
                value: alarms,
                builder: (list) {
                  final received = list.where((a) => a.creator.id != meId);
                  final pending = received
                      .where((a) =>
                          a.recipientFor(meId)?.permissionStatus == PermissionStatus.pending && !_answered.contains(a.id))
                      .toList()
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final accepted = received
                      .where((a) =>
                          a.isActive &&
                          a.nextOccurrenceAt != null &&
                          a.recipientFor(meId)?.permissionStatus == PermissionStatus.accepted)
                      .toList()
                    ..sort((a, b) => a.nextOccurrenceAt!.compareTo(b.nextOccurrenceAt!));

                  if (pending.isEmpty && accepted.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(children: [
                        Text('Sin invitaciones', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Cuando alguien te invite a un momento aparecerá aquí.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ]),
                    );
                  }
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (pending.isNotEmpty) ...[
                        Row(children: [
                          const Eyebrow('Por confirmar'),
                          const SizedBox(width: 8),
                          _Count(pending.length),
                        ]),
                        const SizedBox(height: 12),
                        for (final a in pending) ...[
                          _Invitation(
                            alarm: a,
                            meId: meId,
                            onAccept: () => _answer(a, accept: true),
                            onReject: () => _answer(a, accept: false),
                          ),
                          const SizedBox(height: 14),
                        ],
                        const SizedBox(height: 10),
                      ],
                      if (accepted.isNotEmpty) ...[
                        const Eyebrow('Confirmadas'),
                        const SizedBox(height: 10),
                        Surface(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(children: [
                            for (final (i, a) in accepted.indexed) ...[
                              if (i > 0) const Divider(indent: 16, endIndent: 16),
                              _AcceptedRow(alarm: a, meId: meId),
                            ],
                          ]),
                        ),
                      ],
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final int value;
  const _Count(this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: AppTheme.violet, borderRadius: BorderRadius.circular(10)),
        child: Text('$value', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

/// Invitación pendiente: la hora vuelve a ser el elemento dominante.
class _Invitation extends StatelessWidget {
  final Alarm alarm;
  final String meId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _Invitation({required this.alarm, required this.meId, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = alarm.nextOccurrenceAt ?? alarm.scheduledAt;
    final people = AlarmFormat.participants(alarm);
    final color = momentColor(alarm, meId);
    return Surface(
      padding: const EdgeInsets.all(18),
      onTap: () => context.push('/alarms/${alarm.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(alarm.creator.displayName, size: 34, imageUrl: alarm.creator.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${alarm.creator.displayName.split(' ').first} te invitó',
                  style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(AlarmFormat.ago(alarm.createdAt), style: theme.textTheme.bodySmall),
            ]),
          ),
          const StatusDot('Pendiente', color: AppTheme.warning),
        ]),
        const SizedBox(height: 18),
        Eyebrow(AlarmFormat.day(next), color: color),
        const SizedBox(height: 6),
        BigTime.of(next, size: 50),
        const SizedBox(height: 6),
        Text(alarm.title, style: theme.textTheme.titleLarge),
        if (alarm.repeat != null) Text(AlarmFormat.kind(alarm), style: theme.textTheme.bodySmall),
        if (people.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            AvatarStack(people, size: 24, max: 4),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                SpanishFormatter.joinList(people.take(3).toList()) + (people.length > 3 ? '…' : ''),
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainer,
                foregroundColor: theme.colorScheme.onSurface,
                minimumSize: const Size(0, 48),
              ),
              onPressed: onReject,
              child: const Text('Rechazar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
              onPressed: onAccept,
              child: const Text('Aceptar'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _AcceptedRow extends StatelessWidget {
  final Alarm alarm;
  final String meId;
  const _AcceptedRow({required this.alarm, required this.meId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = momentStatus(alarm, meId);
    final people = AlarmFormat.participants(alarm);
    return InkWell(
      onTap: () => context.push('/alarms/${alarm.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          SizedBox(width: 92, child: BigTime.of(alarm.nextOccurrenceAt!, size: 20)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(alarm.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              StatusDot(status.label, color: status.color, fontSize: 11.5),
            ]),
          ),
          if (people.length > 1) AvatarStack(people, size: 22, max: 3),
        ]),
      ),
    );
  }
}
