import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';

/// Crear un grupo (o editar su nombre/descripción).
class GroupFormScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const GroupFormScreen({super.key, this.groupId});

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _members = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      final group = (ref.read(groupsProvider).value ?? const <Group>[])
          .where((g) => g.id == widget.groupId)
          .firstOrNull;
      _name.text = group?.name ?? '';
      _description.text = group?.description ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final social = ref.read(appServicesProvider).social;
    final description = _description.text.trim().isEmpty ? null : _description.text.trim();
    final group = await runGuarded(
      context,
      () => widget.groupId == null
          ? social.createGroup(_name.text.trim(), description: description, memberIds: _members.toList())
          : social.updateGroup(widget.groupId!, _name.text.trim(), description),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (group != null) {
      if (widget.groupId == null) {
        showMessage(context, _members.isEmpty ? 'Grupo creado.' : 'Grupo creado. Se enviaron las invitaciones.');
        context.pushReplacement('/groups/${group.id}');
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = (ref.watch(contactsProvider).value ?? const <Contact>[]).where((c) => c.isAccepted).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupId == null ? 'Nuevo grupo' : 'Editar grupo')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Familia, Equipo Desarrollo…'),
              maxLength: Validators.maxGroupNameLength,
              validator: Validators.groupName,
              textCapitalization: TextCapitalization.sentences,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              maxLength: Validators.maxGroupDescriptionLength,
              maxLines: 2,
            ),
            if (widget.groupId == null) ...[
              const SectionHeader('Invitar contactos'),
              if (contacts.isEmpty)
                const Text('Agrega contactos para invitarlos al grupo.')
              else
                for (final c in contacts)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: UserAvatar(c.user.displayName, size: 38, imageUrl: c.user.avatarUrl),
                    title: Text(c.user.displayName),
                    subtitle: Text('@${c.user.username}'),
                    value: _members.contains(c.user.id),
                    onChanged: (v) => setState(() => v == true ? _members.add(c.user.id) : _members.remove(c.user.id)),
                  ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(widget.groupId == null ? 'Crear grupo' : 'Guardar'),
          ),
        ),
      ),
    );
  }
}
