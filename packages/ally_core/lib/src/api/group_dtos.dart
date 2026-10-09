import '../domain/enums.dart';
import 'json.dart';
import 'user_dtos.dart';

enum MemberStatus {
  invited('invited'),
  active('active'),
  removed('removed');

  const MemberStatus(this.wire);
  final String wire;
  static MemberStatus fromWire(String w) => values.firstWhere((v) => v.wire == w);
}

class GroupMember {
  final PublicUser user;
  final GroupRole role;
  final MemberStatus status;

  /// El miembro acepta recibir alarmas del grupo.
  final bool allowGroupAlarms;

  /// Las alarmas del grupo se aceptan sin preguntar.
  final bool autoAccept;
  final DateTime? joinedAt;

  const GroupMember({
    required this.user,
    required this.role,
    required this.status,
    this.allowGroupAlarms = true,
    this.autoAccept = true,
    this.joinedAt,
  });

  factory GroupMember.fromJson(JsonMap json) => GroupMember(
        user: PublicUser.fromJson(json['user'] as JsonMap),
        role: GroupRole.fromWire(json['role'] as String),
        status: MemberStatus.fromWire(json['status'] as String),
        allowGroupAlarms: json['allow_group_alarms'] as bool? ?? true,
        autoAccept: json['auto_accept'] as bool? ?? true,
        joinedAt: parseDateTime(json['joined_at']),
      );

  JsonMap toJson() => {
        'user': user.toJson(),
        'role': role.wire,
        'status': status.wire,
        'allow_group_alarms': allowGroupAlarms,
        'auto_accept': autoAccept,
        'joined_at': formatDateTime(joinedAt),
      };
}

/// Quién puede enviar alarmas al grupo.
enum GroupAlarmPolicy {
  members('members'),
  admins('admins');

  const GroupAlarmPolicy(this.wire);
  final String wire;
  static GroupAlarmPolicy fromWire(String w) =>
      values.firstWhere((v) => v.wire == w, orElse: () => GroupAlarmPolicy.members);
}

class Group {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final GroupRole myRole;
  final MemberStatus myStatus;
  final List<GroupMember> members;
  final GroupAlarmPolicy alarmPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.myRole,
    required this.myStatus,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.members = const [],
    this.alarmPolicy = GroupAlarmPolicy.members,
    this.deletedAt,
  });

  int get activeMemberCount =>
      members.where((m) => m.status == MemberStatus.active).length;

  bool get canManage => myRole == GroupRole.owner || myRole == GroupRole.admin;

  /// El usuario puede enviar alarmas al grupo.
  bool get canSendAlarms =>
      myStatus == MemberStatus.active && (alarmPolicy == GroupAlarmPolicy.members || canManage);

  factory Group.fromJson(JsonMap json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        ownerId: json['owner_id'] as String,
        myRole: GroupRole.fromWire(json['my_role'] as String),
        myStatus: MemberStatus.fromWire(json['my_status'] as String? ?? 'active'),
        members: parseList(json['members'], GroupMember.fromJson),
        alarmPolicy: GroupAlarmPolicy.fromWire(json['alarm_policy'] as String? ?? 'members'),
        createdAt: parseRequiredDateTime(json['created_at']),
        updatedAt: parseRequiredDateTime(json['updated_at']),
        deletedAt: parseDateTime(json['deleted_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'owner_id': ownerId,
        'my_role': myRole.wire,
        'my_status': myStatus.wire,
        'members': [for (final m in members) m.toJson()],
        'alarm_policy': alarmPolicy.wire,
        'created_at': formatDateTime(createdAt),
        'updated_at': formatDateTime(updatedAt),
        'deleted_at': formatDateTime(deletedAt),
      };
}
