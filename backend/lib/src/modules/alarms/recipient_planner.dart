import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../contacts/contacts_service.dart';

/// Fila de `alarm_recipients` a crear.
class PlannedRecipient {
  final RecipientType type;
  final String recipientId;
  final String? userId;
  final String? sourceGroupId;
  final PermissionStatus permission;

  const PlannedRecipient({
    required this.type,
    required this.recipientId,
    required this.permission,
    this.userId,
    this.sourceGroupId,
  });

  String get key => '${type.wire}:$recipientId';
}

/// Convierte los destinatarios pedidos en filas concretas aplicando permisos:
///
/// - Usuario: debe ser un contacto aceptado que permita alarmas del creador.
///   Si activó "aceptar automáticamente", queda aceptada; si no, pendiente.
/// - Grupo: el creador debe ser miembro activo; se expande a sus miembros
///   activos que aceptan alarmas del grupo.
/// - Dispositivo: solo dispositivos propios.
class RecipientPlanner {
  final ContactsService contacts;
  RecipientPlanner(this.contacts);

  static const maxExpandedRecipients = 200;

  Future<List<PlannedRecipient>> plan(Db tx, String creatorId, List<RecipientInput> inputs) async {
    if (inputs.length > Validators.maxRecipients) {
      throw const ApiException.badRequest('Demasiados destinatarios para una sola alarma.');
    }
    final planned = <String, PlannedRecipient>{};
    final directUsers = <String>{};

    void add(PlannedRecipient p) => planned.putIfAbsent(p.key, () => p);

    // Primero los usuarios directos (tienen prioridad sobre los de grupo).
    for (final input in inputs.where((i) => i.type == RecipientType.user)) {
      _requireUuid(input.id);
      directUsers.add(input.id);
      if (input.id == creatorId) {
        add(_self(creatorId));
        continue;
      }
      final permissions = await contacts.permissionsGranted(tx, input.id, creatorId);
      if (permissions == null) {
        throw const ApiException.forbidden('Solo puedes enviar alarmas a tus contactos.');
      }
      if (!permissions.allowAlarms) {
        final name = await _displayName(tx, input.id);
        throw ApiException.forbidden('$name no acepta alarmas tuyas.');
      }
      add(PlannedRecipient(
        type: RecipientType.user,
        recipientId: input.id,
        userId: input.id,
        permission: permissions.autoAccept ? PermissionStatus.accepted : PermissionStatus.pending,
      ));
    }

    for (final input in inputs.where((i) => i.type == RecipientType.group)) {
      _requireUuid(input.id);
      final isMember = await tx.one(
        '''
        SELECT m.role, g.alarm_policy FROM group_members m JOIN groups g ON g.id = m.group_id
        WHERE m.group_id = @g::uuid AND m.user_id = @me::uuid AND m.status = 'active' AND g.deleted_at IS NULL
        ''',
        {'g': input.id, 'me': creatorId},
      );
      if (isMember == null) throw const ApiException.forbidden('No perteneces a ese grupo.');
      if (isMember['alarm_policy'] == 'admins' && isMember['role'] == 'member') {
        throw const ApiException.forbidden('Solo los administradores pueden enviar alarmas a este grupo.');
      }
      add(PlannedRecipient(
        type: RecipientType.group,
        recipientId: input.id,
        permission: PermissionStatus.accepted,
      ));
      final members = await tx.query(
        '''
        SELECT user_id::text AS user_id, auto_accept FROM group_members
        WHERE group_id = @g::uuid AND status = 'active' AND allow_group_alarms
        ''',
        {'g': input.id},
      );
      for (final m in members) {
        final userId = m['user_id'] as String;
        if (directUsers.contains(userId)) continue;
        add(PlannedRecipient(
          type: RecipientType.user,
          recipientId: userId,
          userId: userId,
          sourceGroupId: input.id,
          permission: userId == creatorId || m['auto_accept'] as bool
              ? PermissionStatus.accepted
              : PermissionStatus.pending,
        ));
      }
    }

    for (final input in inputs.where((i) => i.type == RecipientType.device)) {
      _requireUuid(input.id);
      final own = await tx.one(
        'SELECT 1 FROM devices WHERE id = @d::uuid AND user_id = @me::uuid AND is_active',
        {'d': input.id, 'me': creatorId},
      );
      if (own == null) throw const ApiException.forbidden('Solo puedes elegir tus propios dispositivos.');
      add(PlannedRecipient(
        type: RecipientType.device,
        recipientId: input.id,
        userId: creatorId,
        permission: PermissionStatus.accepted,
      ));
    }

    // Sin destinatarios: alarma personal.
    if (planned.isEmpty) add(_self(creatorId));
    if (planned.length > maxExpandedRecipients) {
      throw const ApiException.badRequest('La alarma tendría demasiados destinatarios.');
    }
    return planned.values.toList();
  }

  static PlannedRecipient _self(String creatorId) => PlannedRecipient(
        type: RecipientType.user,
        recipientId: creatorId,
        userId: creatorId,
        permission: PermissionStatus.accepted,
      );

  static void _requireUuid(String id) {
    if (!Validators.isUuid(id)) {
      throw const ApiException.badRequest('Algún destinatario no es válido.');
    }
  }

  static Future<String> _displayName(Db tx, String userId) async {
    final row = await tx.one('SELECT display_name FROM users WHERE id = @id::uuid', {'id': userId});
    return row?['display_name'] as String? ?? 'Esta persona';
  }
}
