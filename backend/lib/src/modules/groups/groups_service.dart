import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../notifications/notification_service.dart';
import '../users/users_repository.dart';

class GroupInput {
  final String name;
  final String? description;
  final List<String> memberIds;
  final GroupAlarmPolicy? alarmPolicy;

  const GroupInput({required this.name, this.description, this.memberIds = const [], this.alarmPolicy});

  factory GroupInput.fromJson(JsonMap json) => GroupInput(
        name: (json['name'] as String? ?? '').trim(),
        description: (json['description'] as String?)?.trim(),
        memberIds: List<String>.from(json['member_ids'] as List? ?? const []),
        alarmPolicy: json['alarm_policy'] == null
            ? null
            : GroupAlarmPolicy.fromWire(json['alarm_policy'] as String),
      );

  void validate() {
    final errors = FieldErrors()..check('name', Validators.groupName(name));
    if ((description?.length ?? 0) > Validators.maxGroupDescriptionLength) {
      errors.add('description', 'La descripción es demasiado larga.');
    }
    if (memberIds.any((id) => !Validators.isUuid(id))) {
      errors.add('member_ids', 'Algún miembro no es válido.');
    }
    if (memberIds.length > 100) errors.add('member_ids', 'Un grupo puede tener hasta 100 miembros.');
    errors.throwIfAny();
  }
}

class GroupsService {
  final Db db;
  final NotificationService notifications;

  GroupsService(this.db, this.notifications);

  /// Grupos visibles para el usuario (miembro activo o invitado), con miembros.
  Future<List<Group>> list(String me) async {
    final rows = await db.query(
      '''
      SELECT g.id::text AS id, g.name, g.description, g.owner_id::text AS owner_id,
             g.created_at, g.updated_at, g.deleted_at, g.alarm_policy, m.role AS my_role, m.status AS my_status
      FROM groups g JOIN group_members m ON m.group_id = g.id AND m.user_id = @me::uuid
      WHERE m.status <> 'removed' AND g.deleted_at IS NULL
      ORDER BY g.name
      ''',
      {'me': me},
    );
    if (rows.isEmpty) return const [];
    final members = await _members([for (final r in rows) r['id'] as String]);
    return [for (final r in rows) _groupFromRow(r, members[r['id']] ?? const [])];
  }

  Future<Group> get(String me, String groupId) async {
    final row = await db.one(
      '''
      SELECT g.id::text AS id, g.name, g.description, g.owner_id::text AS owner_id,
             g.created_at, g.updated_at, g.deleted_at, g.alarm_policy, m.role AS my_role, m.status AS my_status
      FROM groups g JOIN group_members m ON m.group_id = g.id AND m.user_id = @me::uuid
      WHERE g.id = @id::uuid AND m.status <> 'removed' AND g.deleted_at IS NULL
      ''',
      {'me': me, 'id': groupId},
    );
    if (row == null) throw const ApiException.notFound('No encontramos ese grupo.');
    final members = await _members([groupId]);
    return _groupFromRow(row, members[groupId] ?? const []);
  }

  Future<Group> create(String me, GroupInput input) async {
    input.validate();
    final memberIds = {...input.memberIds}..remove(me);
    final groupId = await db.transaction((tx) async {
      await _requireContacts(tx, me, memberIds);
      final row = await tx.one(
        'INSERT INTO groups (name, description, owner_id) VALUES (@n, @d, @me::uuid) RETURNING id::text AS id',
        {'n': input.name, 'd': input.description, 'me': me},
      );
      final id = row!['id'] as String;
      await tx.execute(
        "INSERT INTO group_members (group_id, user_id, role, status, joined_at) "
        "VALUES (@g::uuid, @me::uuid, 'owner', 'active', now())",
        {'g': id, 'me': me},
      );
      await _invite(tx, id, me, memberIds);
      return id;
    });
    await _notifyInvited(me, groupId, input.name, memberIds);
    return get(me, groupId);
  }

  Future<Group> update(String me, String groupId, GroupInput input) async {
    input.validate();
    await _requireManager(me, groupId);
    await db.execute(
      'UPDATE groups SET name = @n, description = @d, alarm_policy = COALESCE(@p, alarm_policy) WHERE id = @id::uuid',
      {'id': groupId, 'n': input.name, 'd': input.description, 'p': input.alarmPolicy?.wire},
    );
    return get(me, groupId);
  }

  Future<void> delete(String me, String groupId) async {
    final updated = await db.execute(
      'UPDATE groups SET deleted_at = now() WHERE id = @id::uuid AND owner_id = @me::uuid AND deleted_at IS NULL',
      {'id': groupId, 'me': me},
    );
    if (updated == 0) throw const ApiException.forbidden('Solo el creador puede eliminar el grupo.');
  }

  Future<Group> addMembers(String me, String groupId, List<String> userIds) async {
    if (userIds.isEmpty || userIds.any((id) => !Validators.isUuid(id))) {
      throw const ApiException.badRequest('Indica a quién quieres agregar.');
    }
    final group = await _requireManager(me, groupId);
    final ids = {...userIds}..remove(me);
    final invited = await db.transaction((tx) async {
      await _requireContacts(tx, me, ids);
      return _invite(tx, groupId, me, ids);
    });
    await _notifyInvited(me, groupId, group.name, invited);
    return get(me, groupId);
  }

  /// Quitar a otro miembro (owner/admin) o salir del grupo (uno mismo).
  Future<void> removeMember(String me, String groupId, String userId) async {
    final group = await get(me, groupId);
    if (userId == group.ownerId) {
      throw const ApiException.badRequest(
        'El creador no puede salir del grupo. Puedes eliminarlo.',
      );
    }
    if (userId != me && !group.canManage) throw const ApiException.forbidden();
    final updated = await db.execute(
      "UPDATE group_members SET status = 'removed' WHERE group_id = @g::uuid AND user_id = @u::uuid "
      "AND status <> 'removed'",
      {'g': groupId, 'u': userId},
    );
    if (updated == 0) throw const ApiException.notFound('Esa persona no es miembro del grupo.');
  }

  Future<Group> acceptInvitation(String me, String groupId) async {
    final updated = await db.execute(
      "UPDATE group_members SET status = 'active', joined_at = now() "
      "WHERE group_id = @g::uuid AND user_id = @me::uuid AND status = 'invited' "
      'AND EXISTS (SELECT 1 FROM groups WHERE id = @g::uuid AND deleted_at IS NULL)',
      {'g': groupId, 'me': me},
    );
    if (updated == 0) throw const ApiException.notFound('La invitación ya no está disponible.');
    return get(me, groupId);
  }

  Future<Group> updateMySettings(
    String me,
    String groupId, {
    required bool allowGroupAlarms,
    required bool autoAccept,
  }) async {
    final updated = await db.execute(
      'UPDATE group_members SET allow_group_alarms = @allow, auto_accept = @auto '
      "WHERE group_id = @g::uuid AND user_id = @me::uuid AND status <> 'removed'",
      {'g': groupId, 'me': me, 'allow': allowGroupAlarms, 'auto': allowGroupAlarms && autoAccept},
    );
    if (updated == 0) throw const ApiException.notFound('No encontramos ese grupo.');
    return get(me, groupId);
  }

  Future<Group> setRole(String me, String groupId, String userId, GroupRole role) async {
    if (role == GroupRole.owner) {
      throw const ApiException.badRequest('No se puede asignar el rol de creador.');
    }
    final group = await get(me, groupId);
    if (group.myRole != GroupRole.owner) {
      throw const ApiException.forbidden('Solo el creador puede cambiar los roles.');
    }
    final updated = await db.execute(
      "UPDATE group_members SET role = @r WHERE group_id = @g::uuid AND user_id = @u::uuid AND role <> 'owner'",
      {'g': groupId, 'u': userId, 'r': role.wire},
    );
    if (updated == 0) throw const ApiException.notFound('Esa persona no es miembro del grupo.');
    return get(me, groupId);
  }

  // ------------------------------------------------------------ internos

  Future<Group> _requireManager(String me, String groupId) async {
    final group = await get(me, groupId);
    if (!group.canManage || group.myStatus != MemberStatus.active) {
      throw const ApiException.forbidden('Solo los administradores pueden modificar el grupo.');
    }
    return group;
  }

  /// Solo se puede invitar a contactos aceptados.
  Future<void> _requireContacts(Db tx, String me, Set<String> ids) async {
    if (ids.isEmpty) return;
    final rows = await tx.query(
      '''
      SELECT CASE WHEN requester_id = @me::uuid THEN addressee_id ELSE requester_id END::text AS other
      FROM connections
      WHERE status = 'accepted' AND (requester_id = @me::uuid OR addressee_id = @me::uuid)
        AND (CASE WHEN requester_id = @me::uuid THEN addressee_id ELSE requester_id END) = ANY(@ids::uuid[])
      ''',
      {'me': me, 'ids': ids.toList()},
    );
    if (rows.length != ids.length) {
      throw const ApiException.badRequest('Solo puedes agregar a personas que estén entre tus contactos.');
    }
  }

  /// Invita (o vuelve a invitar) y devuelve los usuarios realmente invitados.
  Future<Set<String>> _invite(Db tx, String groupId, String me, Set<String> ids) async {
    final invited = <String>{};
    for (final id in ids) {
      final row = await tx.one(
        '''
        INSERT INTO group_members (group_id, user_id, role, status, invited_by)
        VALUES (@g::uuid, @u::uuid, 'member', 'invited', @me::uuid)
        ON CONFLICT (group_id, user_id) DO UPDATE SET status = 'invited', invited_by = @me::uuid
          WHERE group_members.status = 'removed'
        RETURNING user_id
        ''',
        {'g': groupId, 'u': id, 'me': me},
      );
      if (row != null) invited.add(id);
    }
    return invited;
  }

  Future<void> _notifyInvited(String me, String groupId, String name, Set<String> ids) async {
    if (ids.isEmpty) return;
    final inviter = await UsersRepository(db).findById(me);
    await notifications.notifyAll([
      for (final id in ids)
        OutgoingNotification(
          userId: id,
          type: NotificationType.groupInvitation,
          title: 'Invitación a grupo',
          body: '${inviter?.displayName ?? 'Alguien'} te invitó al grupo "$name".',
          data: {'group_id': groupId},
          dedupeKey: 'group_invitation:$groupId:$id:${DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000}',
        ),
    ]);
  }

  Future<Map<String, List<GroupMember>>> _members(List<String> groupIds) async {
    final rows = await db.query(
      '''
      SELECT m.group_id::text AS group_id, m.role, m.status, m.allow_group_alarms, m.auto_accept,
             m.joined_at, ${publicUserColumns('u')}
      FROM group_members m JOIN users u ON u.id = m.user_id
      WHERE m.group_id = ANY(@ids::uuid[]) AND m.status <> 'removed' AND u.deleted_at IS NULL
      ORDER BY (m.role = 'owner') DESC, u.display_name
      ''',
      {'ids': groupIds},
    );
    final result = <String, List<GroupMember>>{};
    for (final r in rows) {
      result.putIfAbsent(r['group_id'] as String, () => []).add(GroupMember(
            user: publicUserFromRow(r),
            role: GroupRole.fromWire(r['role'] as String),
            status: MemberStatus.fromWire(r['status'] as String),
            allowGroupAlarms: r['allow_group_alarms'] as bool,
            autoAccept: r['auto_accept'] as bool,
            joinedAt: r['joined_at'] as DateTime?,
          ));
    }
    return result;
  }

  Group _groupFromRow(Row r, List<GroupMember> members) => Group(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description'] as String?,
        ownerId: r['owner_id'] as String,
        myRole: GroupRole.fromWire(r['my_role'] as String),
        myStatus: MemberStatus.fromWire(r['my_status'] as String),
        members: members,
        alarmPolicy: GroupAlarmPolicy.fromWire(r['alarm_policy'] as String),
        createdAt: r['created_at'] as DateTime,
        updatedAt: r['updated_at'] as DateTime,
        deletedAt: r['deleted_at'] as DateTime?,
      );
}
