import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../application/session_controller.dart';
import '../../core/widgets/common.dart';

/// Contactos y grupos.
class PeopleScreen extends ConsumerWidget {
  final String? initialTab;
  const PeopleScreen({super.key, this.initialTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == 'groups' ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personas'),
          actions: [
            IconButton(
              tooltip: 'Agregar contacto',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => context.push('/contacts/add'),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Contactos'), Tab(text: 'Grupos')]),
        ),
        body: const TabBarView(children: [_ContactsTab(), _GroupsTab()]),
      ),
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    return AsyncBody(
      value: contacts,
      builder: (list) {
        final incoming = list.where((c) => c.isPendingIncoming).toList();
        final accepted = list.where((c) => c.isAccepted).toList();
        final outgoing = list
            .where((c) => c.status == ConnectionStatus.pending && c.direction == ConnectionDirection.outgoing)
            .toList();
        final blocked = list.where((c) => c.status == ConnectionStatus.blocked).toList();
        return RefreshIndicator(
          onRefresh: () async => ref.read(sessionProvider.notifier).syncNow(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (incoming.isNotEmpty)
                AppCard(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  onTap: () => context.push('/contacts/requests'),
                  child: Row(children: [
                    const Icon(Icons.mark_email_unread_rounded),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${incoming.length} solicitud(es) de conexión')),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              if (accepted.isEmpty && incoming.isEmpty)
                EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Aún no tienes contactos',
                  message: 'Agrega a alguien por su @usuario, correo, teléfono o con un código QR.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/contacts/add'),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Agregar contacto'),
                  ),
                ),
              if (accepted.isNotEmpty) ...[
                const SectionHeader('Contactos'),
                for (final c in accepted) _ContactTile(contact: c),
              ],
              if (outgoing.isNotEmpty) ...[
                const SectionHeader('Solicitudes enviadas'),
                for (final c in outgoing) _ContactTile(contact: c, subtitle: 'Esperando respuesta'),
              ],
              if (blocked.isNotEmpty) ...[
                const SectionHeader('Bloqueados'),
                for (final c in blocked) _ContactTile(contact: c, subtitle: 'Bloqueado'),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final String? subtitle;
  const _ContactTile({required this.contact, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final auto = contact.grantedByMe.autoAccept;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: UserAvatar(contact.user.displayName, imageUrl: contact.user.avatarUrl),
      title: Text(contact.user.displayName),
      subtitle: Text(subtitle ?? '@${contact.user.username}${auto ? ' · acepta automáticamente' : ''}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/contacts/${contact.connectionId}'),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-group',
        onPressed: () => context.push('/groups/new'),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Crear grupo'),
      ),
      body: AsyncBody(
        value: groups,
        builder: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.groups_2_outlined,
                title: 'Sin grupos',
                message: 'Crea un grupo como "Familia" o "Equipo Desarrollo" para enviar alarmas a todos.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  for (final g in list)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: UserAvatar(g.name, icon: Icons.groups_rounded),
                      title: Text(g.name),
                      subtitle: Text(g.myStatus == MemberStatus.invited
                          ? 'Invitación pendiente'
                          : '${g.activeMemberCount} miembro(s)'),
                      trailing: g.myStatus == MemberStatus.invited
                          ? const Icon(Icons.mark_email_unread_rounded)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/groups/${g.id}'),
                    ),
                ],
              ),
      ),
    );
  }
}
