import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';

/// Perfil de un contacto y permisos que le concedo.
class ContactScreen extends ConsumerWidget {
  final String connectionId;
  const ContactScreen({super.key, required this.connectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final social = ref.read(appServicesProvider).social;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: AsyncBody(
        value: contacts,
        builder: (list) {
          final contact = list.where((c) => c.connectionId == connectionId).firstOrNull;
          if (contact == null) {
            return const EmptyState(icon: Icons.person_off_rounded, title: 'Este contacto ya no está disponible');
          }
          final p = contact.grantedByMe;
          Future<void> update(ConnectionPermissions next) =>
              runGuarded(context, () => social.updatePermissions(connectionId, next));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(child: UserAvatar(contact.user.displayName, size: 88, imageUrl: contact.user.avatarUrl)),
              const SizedBox(height: 12),
              Text(contact.user.displayName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              Text('@${contact.user.username}', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              if (contact.isAccepted) ...[
                FilledButton.icon(
                  onPressed: contact.grantedToMe.allowAlarms
                      ? () => context.push('/alarms/new?user=${contact.user.id}')
                      : null,
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: Text(contact.grantedToMe.allowAlarms
                      ? 'Enviar alarma'
                      : '${contact.user.displayName} no acepta alarmas'),
                ),
                if (contact.grantedToMe.allowAlarms) ...[
                  const SizedBox(height: 6),
                  Text(
                    contact.grantedToMe.autoAccept
                        ? 'Tus alarmas le llegarán directamente.'
                        : 'Deberá aceptar cada alarma que le envíes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                SectionHeader('Lo que ${contact.user.displayName.split(' ').first} puede hacer'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    SwitchListTile(
                      title: const Text('Permitir alarmas'),
                      subtitle: const Text('Puede enviarte alarmas'),
                      value: p.allowAlarms,
                      onChanged: (v) => update(p.copyWith(allowAlarms: v, autoAccept: v && p.autoAccept)),
                    ),
                    SwitchListTile(
                      title: const Text('Permitir automáticamente todas sus alarmas'),
                      subtitle: const Text('No tendrás que aceptar cada alarma'),
                      value: p.autoAccept,
                      onChanged: p.allowAlarms ? (v) => update(p.copyWith(autoAccept: v)) : null,
                    ),
                    SwitchListTile(
                      title: const Text('Permitir ver confirmación'),
                      subtitle: const Text('Verá si confirmaste, pospusiste o descartaste'),
                      value: p.shareResponseStatus,
                      onChanged: (v) => update(p.copyWith(shareResponseStatus: v)),
                    ),
                  ]),
                ),
              ],
              if (contact.status == ConnectionStatus.pending && contact.direction == ConnectionDirection.outgoing)
                const Text('Solicitud enviada. Esperando respuesta.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (contact.status == ConnectionStatus.blocked)
                OutlinedButton(
                  onPressed: () async {
                    await runGuarded(context, () => social.unblock(connectionId), success: 'Usuario desbloqueado.');
                    if (context.mounted) context.pop();
                  },
                  child: const Text('Desbloquear'),
                )
              else ...[
                OutlinedButton(
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Eliminar contacto',
                        message: 'Dejarán de poder enviarse alarmas.',
                        confirm: 'Eliminar',
                        destructive: true);
                    if (!ok || !context.mounted) return;
                    await runGuarded(context, () => social.remove(connectionId));
                    if (context.mounted) context.pop();
                  },
                  child: const Text('Eliminar contacto'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Bloquear',
                        message: 'No podrá enviarte solicitudes ni alarmas, y sus alarmas actuales dejarán de sonar.',
                        confirm: 'Bloquear',
                        destructive: true);
                    if (!ok || !context.mounted) return;
                    await runGuarded(context, () => social.block(connectionId), success: 'Usuario bloqueado.');
                  },
                  child: const Text('Bloquear'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
