import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';

/// Solicitudes de conexión recibidas: aceptar, rechazar o bloquear.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final social = ref.read(appServicesProvider).social;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes')),
      body: AsyncBody(
        value: contacts,
        builder: (list) {
          final incoming = list.where((c) => c.isPendingIncoming).toList();
          if (incoming.isEmpty) {
            return const EmptyState(icon: Icons.inbox_rounded, title: 'No tienes solicitudes pendientes');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: incoming.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = incoming[i];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      UserAvatar(c.user.displayName, imageUrl: c.user.avatarUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.user.displayName, style: Theme.of(context).textTheme.titleMedium),
                          Text('@${c.user.username} quiere conectarse contigo'),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      TextButton(
                        onPressed: () async {
                          final ok = await confirmDialog(context,
                              title: 'Bloquear',
                              message: '${c.user.displayName} no podrá enviarte solicitudes ni alarmas.',
                              confirm: 'Bloquear',
                              destructive: true);
                          if (ok && context.mounted) {
                            await runGuarded(context, () => social.block(c.connectionId), success: 'Usuario bloqueado.');
                          }
                        },
                        child: const Text('Bloquear'),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => runGuarded(context, () => social.reject(c.connectionId)),
                        child: const Text('Rechazar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => runGuarded(
                          context,
                          () => social.accept(c.connectionId),
                          success: 'Ahora estás conectado con ${c.user.displayName}.',
                        ),
                        child: const Text('Aceptar'),
                      ),
                    ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
