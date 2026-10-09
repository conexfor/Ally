import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';

/// Detalle del grupo: miembros, invitaciones, permisos y administración.
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final me = ref.watch(meProvider).value;
    final social = ref.read(appServicesProvider).social;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: AsyncBody(
        value: groups,
        builder: (list) {
          final group = list.where((g) => g.id == groupId).firstOrNull;
          if (group == null) {
            return const EmptyState(icon: Icons.group_off_rounded, title: 'Este grupo ya no está disponible');
          }
          final mine = group.members.where((m) => m.user.id == me?.id).firstOrNull;
          final invited = group.myStatus == MemberStatus.invited;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(child: UserAvatar(group.name, size: 84, icon: Icons.groups_rounded)),
              const SizedBox(height: 12),
              Text(group.name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              if (group.description != null)
                Text(group.description!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              if (invited)
                AppCard(
                  color: theme.colorScheme.tertiaryContainer,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Te invitaron a este grupo. Al unirte podrás recibir sus alarmas.'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await runGuarded(context, () => social.leaveGroup(groupId));
                            if (context.mounted) context.pop();
                          },
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => runGuarded(context, () => social.acceptGroup(groupId), success: 'Te uniste al grupo.'),
                          child: const Text('Unirme'),
                        ),
                      ),
                    ]),
                  ]),
                )
              else ...[
                FilledButton.icon(
                  onPressed: group.canSendAlarms ? () => context.push('/alarms/new?group=$groupId') : null,
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: const Text('Alarma para el grupo'),
                ),
                if (!group.canSendAlarms)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Solo los administradores pueden enviar alarmas a este grupo.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (group.canManage) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo administradores envían alarmas'),
                    subtitle: const Text('Los demás miembros solo las reciben.'),
                    value: group.alarmPolicy == GroupAlarmPolicy.admins,
                    onChanged: (v) => runGuarded(
                      context,
                      () => social.updateGroup(
                        groupId,
                        group.name,
                        group.description,
                        alarmPolicy: v ? GroupAlarmPolicy.admins : GroupAlarmPolicy.members,
                      ),
                    ),
                  ),
                ],
              ],
              SectionHeader(
                'Miembros (${group.activeMemberCount})',
                trailing: group.canManage && !invited
                    ? TextButton.icon(
                        onPressed: () => _addMembers(context, ref, group),
                        icon: const Icon(Icons.person_add_alt_rounded),
                        label: const Text('Agregar'),
                      )
                    : null,
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final m in group.members)
                    ListTile(
                      leading: UserAvatar(m.user.displayName, size: 38, imageUrl: m.user.avatarUrl),
                      title: Text(m.user.id == me?.id ? '${m.user.displayName} (tú)' : m.user.displayName),
                      subtitle: Text([
                        switch (m.role) {
                          GroupRole.owner => 'Creador',
                          GroupRole.admin => 'Administrador',
                          GroupRole.member => 'Miembro',
                        },
                        if (m.status == MemberStatus.invited) 'invitación pendiente',
                        if (m.status == MemberStatus.active && !m.allowGroupAlarms) 'no recibe alarmas',
                      ].join(' · ')),
                      trailing: group.canManage && m.role != GroupRole.owner && m.user.id != me?.id
                          ? PopupMenuButton<String>(
                              onSelected: (action) async {
                                switch (action) {
                                  case 'admin':
                                    await runGuarded(context, () => social.setRole(groupId, m.user.id, GroupRole.admin));
                                  case 'member':
                                    await runGuarded(context, () => social.setRole(groupId, m.user.id, GroupRole.member));
                                  case 'remove':
                                    final ok = await confirmDialog(context,
                                        title: 'Quitar del grupo',
                                        message: '${m.user.displayName} dejará de recibir las alarmas del grupo.',
                                        confirm: 'Quitar',
                                        destructive: true);
                                    if (ok && context.mounted) {
                                      await runGuarded(context, () => social.removeMember(groupId, m.user.id));
                                    }
                                }
                              },
                              itemBuilder: (_) => [
                                if (group.myRole == GroupRole.owner && m.role == GroupRole.member)
                                  const PopupMenuItem(value: 'admin', child: Text('Hacer administrador')),
                                if (group.myRole == GroupRole.owner && m.role == GroupRole.admin)
                                  const PopupMenuItem(value: 'member', child: Text('Quitar como administrador')),
                                const PopupMenuItem(value: 'remove', child: Text('Quitar del grupo')),
                              ],
                            )
                          : null,
                    ),
                ]),
              ),
              if (mine != null && !invited) ...[
                const SectionHeader('Mis permisos en este grupo'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    SwitchListTile(
                      title: const Text('Recibir alarmas del grupo'),
                      value: mine.allowGroupAlarms,
                      onChanged: (v) => runGuarded(
                        context,
                        () => social.updateMembership(groupId, allowAlarms: v, autoAccept: v && mine.autoAccept),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Aceptarlas automáticamente'),
                      value: mine.autoAccept,
                      onChanged: mine.allowGroupAlarms
                          ? (v) => runGuarded(
                                context,
                                () => social.updateMembership(groupId, allowAlarms: true, autoAccept: v),
                              )
                          : null,
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              if (group.myRole == GroupRole.owner) ...[
                OutlinedButton.icon(
                  onPressed: () => context.push('/groups/$groupId/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar grupo'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Eliminar grupo',
                        message: 'Se eliminará para todos los miembros.',
                        confirm: 'Eliminar',
                        destructive: true);
                    if (!ok || !context.mounted) return;
                    await runGuarded(context, () => social.deleteGroup(groupId));
                    if (context.mounted) context.pop();
                  },
                  child: const Text('Eliminar grupo'),
                ),
              ] else if (!invited)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Salir del grupo', message: 'Dejarás de recibir sus alarmas.', confirm: 'Salir', destructive: true);
                    if (!ok || !context.mounted) return;
                    await runGuarded(context, () => social.leaveGroup(groupId));
                    if (context.mounted) context.pop();
                  },
                  child: const Text('Salir del grupo'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addMembers(BuildContext context, WidgetRef ref, Group group) async {
    final current = {for (final m in group.members) m.user.id};
    final candidates = (ref.read(contactsProvider).value ?? const <Contact>[])
        .where((c) => c.isAccepted && !current.contains(c.user.id))
        .toList();
    if (candidates.isEmpty) {
      showMessage(context, 'Todos tus contactos ya están en el grupo.');
      return;
    }
    final selected = <String>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(title: Text('Invitar al grupo')),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in candidates)
                  CheckboxListTile(
                    title: Text(c.user.displayName),
                    subtitle: Text('@${c.user.username}'),
                    value: selected.contains(c.user.id),
                    onChanged: (v) => setState(() => v == true ? selected.add(c.user.id) : selected.remove(c.user.id)),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Invitar')),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || selected.isEmpty || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(appServicesProvider).social.addMembers(group.id, selected.toList()),
      success: 'Invitaciones enviadas.',
    );
  }
}
