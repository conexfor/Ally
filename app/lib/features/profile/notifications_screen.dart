import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/utils/alarm_format.dart';
import '../../core/widgets/common.dart';
import '../../services/local_notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _page = 50;
  int _limit = _page;
  bool _loadingMore = false;
  bool _serverExhausted = false;

  static IconData _icon(NotificationType type) => switch (type) {
        NotificationType.alarmNew || NotificationType.alarmRequest => Icons.alarm_add_rounded,
        NotificationType.alarmUpdated => Icons.edit_calendar_rounded,
        NotificationType.alarmCancelled => Icons.alarm_off_rounded,
        NotificationType.alarmConfirmed => Icons.check_circle_rounded,
        NotificationType.alarmSnoozed => Icons.snooze_rounded,
        NotificationType.alarmDismissed => Icons.notifications_off_rounded,
        NotificationType.alarmTriggered => Icons.alarm_rounded,
        NotificationType.connectionRequest || NotificationType.connectionAccepted => Icons.person_add_alt_1_rounded,
        NotificationType.groupInvitation => Icons.group_add_rounded,
        NotificationType.syncRequired => Icons.sync_rounded,
      };

  /// Muestra más: primero las ya guardadas y, si no hay, pide anteriores al
  /// servidor.
  Future<void> _loadMore(List<AppNotification> shown) async {
    setState(() => _loadingMore = true);
    final services = ref.read(appServicesProvider);
    try {
      if (shown.length >= _limit && !_serverExhausted) {
        final older = await services.api.notifications(before: shown.last.createdAt, limit: _page);
        for (final n in older) {
          await services.store.upsertNotification(n);
        }
        _serverExhausted = older.length < _page;
      }
      setState(() => _limit += _page);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider(_limit));
    final services = ref.read(appServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () async {
              await services.store.markNotificationsRead();
              try {
                await services.api.markAllNotificationsRead();
              } catch (_) {}
            },
            child: const Text('Marcar leídas'),
          ),
        ],
      ),
      body: AsyncBody(
        value: notifications,
        builder: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.notifications_none_rounded, title: 'Sin notificaciones')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == list.length) {
                    final canLoadMore = list.length >= _limit || !_serverExhausted;
                    if (!canLoadMore) return const SizedBox.shrink();
                    return _loadingMore
                        ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                        : OutlinedButton(onPressed: () => _loadMore(list), child: const Text('Cargar anteriores'));
                  }
                  final n = list[i];
                  return AppCard(
                    color: n.isRead ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                    onTap: () async {
                      await services.store.markNotificationsRead(id: n.id);
                      try {
                        await services.api.markNotificationRead(n.id);
                      } catch (_) {}
                      if (context.mounted) {
                        context.push(LocalNotificationService.routeFor(n.type, n.alarmId, n.data));
                      }
                    },
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(_icon(n.type), color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(n.body),
                          const SizedBox(height: 4),
                          Text(
                            '${AlarmFormat.day(n.createdAt)} · ${AlarmFormat.time(n.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
