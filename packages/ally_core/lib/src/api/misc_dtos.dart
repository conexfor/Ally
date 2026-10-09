import '../domain/enums.dart';
import 'alarm_dtos.dart';
import 'contact_dtos.dart';
import 'group_dtos.dart';
import 'json.dart';

class Device {
  final String id;
  final String deviceName;
  final DeviceType deviceType;
  final DevicePlatform platform;
  final String? timezone;
  final bool isActive;

  /// El usuario quiere que las alarmas suenen en este dispositivo.
  final bool receivesAlarms;
  final DateTime? lastSeenAt;

  const Device({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    this.timezone,
    this.isActive = true,
    this.receivesAlarms = true,
    this.lastSeenAt,
  });

  factory Device.fromJson(JsonMap json) => Device(
        id: json['id'] as String,
        deviceName: json['device_name'] as String,
        deviceType: DeviceType.fromWire(json['device_type'] as String),
        platform: DevicePlatform.fromWire(json['platform'] as String),
        timezone: json['timezone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        receivesAlarms: json['receives_alarms'] as bool? ?? true,
        lastSeenAt: parseDateTime(json['last_seen_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'device_name': deviceName,
        'device_type': deviceType.wire,
        'platform': platform.wire,
        'timezone': timezone,
        'is_active': isActive,
        'receives_alarms': receivesAlarms,
        'last_seen_at': formatDateTime(lastSeenAt),
      };
}

/// Registro/actualización del dispositivo actual.
class DeviceInput {
  final String? id;
  final String deviceName;
  final DeviceType deviceType;
  final DevicePlatform platform;
  final String? pushToken;
  final String timezone;
  final String? appVersion;

  const DeviceInput({
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    required this.timezone,
    this.id,
    this.pushToken,
    this.appVersion,
  });

  factory DeviceInput.fromJson(JsonMap json) => DeviceInput(
        id: json['id'] as String?,
        deviceName: (json['device_name'] as String? ?? '').trim(),
        deviceType: DeviceType.fromWire(json['device_type'] as String? ?? 'phone'),
        platform: DevicePlatform.fromWire(json['platform'] as String? ?? 'other'),
        pushToken: json['push_token'] as String?,
        timezone: json['timezone'] as String? ?? 'UTC',
        appVersion: json['app_version'] as String?,
      );

  JsonMap toJson() => {
        if (id != null) 'id': id,
        'device_name': deviceName,
        'device_type': deviceType.wire,
        'platform': platform.wire,
        'push_token': pushToken,
        'timezone': timezone,
        'app_version': appVersion,
      };
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final JsonMap data;
  final String? alarmId;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.alarmId,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(JsonMap json) => AppNotification(
        id: json['id'] as String,
        type: NotificationType.fromWire(json['type'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
        alarmId: json['alarm_id'] as String?,
        readAt: parseDateTime(json['read_at']),
        createdAt: parseRequiredDateTime(json['created_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'type': type.wire,
        'title': title,
        'body': body,
        'data': data,
        'alarm_id': alarmId,
        'read_at': formatDateTime(readAt),
        'created_at': formatDateTime(createdAt),
      };
}

/// Cambios desde el último cursor de sincronización.
class SyncPayload {
  /// Cursor a enviar en la próxima sincronización.
  final int cursor;
  final DateTime serverTime;
  final List<Alarm> alarms;
  final List<AlarmResponse> responses;
  final List<Contact> contacts;
  final List<Group> groups;
  final List<AppNotification> notifications;

  /// Indica que el cliente debe descartar su copia local y quedarse con esta.
  final bool fullResync;

  /// Hay más cambios: el cliente debe volver a sincronizar con [cursor].
  final bool hasMore;

  const SyncPayload({
    required this.cursor,
    required this.serverTime,
    this.alarms = const [],
    this.responses = const [],
    this.contacts = const [],
    this.groups = const [],
    this.notifications = const [],
    this.fullResync = false,
    this.hasMore = false,
  });

  factory SyncPayload.fromJson(JsonMap json) => SyncPayload(
        cursor: (json['cursor'] as num).toInt(),
        serverTime: parseRequiredDateTime(json['server_time']),
        alarms: parseList(json['alarms'], Alarm.fromJson),
        responses: parseList(json['responses'], AlarmResponse.fromJson),
        contacts: parseList(json['contacts'], Contact.fromJson),
        groups: parseList(json['groups'], Group.fromJson),
        notifications: parseList(json['notifications'], AppNotification.fromJson),
        fullResync: json['full_resync'] as bool? ?? false,
        hasMore: json['has_more'] as bool? ?? false,
      );

  JsonMap toJson() => {
        'cursor': cursor,
        'server_time': formatDateTime(serverTime),
        'alarms': [for (final a in alarms) a.toJson()],
        'responses': [for (final r in responses) r.toJson()],
        'contacts': [for (final c in contacts) c.toJson()],
        'groups': [for (final g in groups) g.toJson()],
        'notifications': [for (final n in notifications) n.toJson()],
        'full_resync': fullResync,
        'has_more': hasMore,
      };
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(JsonMap json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: parseRequiredDateTime(json['created_at']),
        updatedAt: parseRequiredDateTime(json['updated_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title,
        'created_at': formatDateTime(createdAt),
        'updated_at': formatDateTime(updatedAt),
      };
}

class ChatMessage {
  final String id;
  final String sessionId;
  final ChatRole role;
  final String content;

  /// Resultado de interpretación asociado (borrador, aclaraciones...).
  final JsonMap? payload;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.payload,
  });

  factory ChatMessage.fromJson(JsonMap json) => ChatMessage(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        role: ChatRole.fromWire(json['role'] as String),
        content: json['content'] as String,
        payload: json['payload'] as JsonMap?,
        createdAt: parseRequiredDateTime(json['created_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'session_id': sessionId,
        'role': role.wire,
        'content': content,
        'payload': payload,
        'created_at': formatDateTime(createdAt),
      };
}

/// Totales para el panel de estadísticas.
class AlarmStats {
  final int created;
  final int received;
  final int confirmed;
  final int snoozed;
  final int dismissed;
  final int cancelled;

  const AlarmStats({
    this.created = 0,
    this.received = 0,
    this.confirmed = 0,
    this.snoozed = 0,
    this.dismissed = 0,
    this.cancelled = 0,
  });

  factory AlarmStats.fromJson(JsonMap json) => AlarmStats(
        created: (json['created'] as num?)?.toInt() ?? 0,
        received: (json['received'] as num?)?.toInt() ?? 0,
        confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
        snoozed: (json['snoozed'] as num?)?.toInt() ?? 0,
        dismissed: (json['dismissed'] as num?)?.toInt() ?? 0,
        cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      );

  JsonMap toJson() => {
        'created': created,
        'received': received,
        'confirmed': confirmed,
        'snoozed': snoozed,
        'dismissed': dismissed,
        'cancelled': cancelled,
      };
}

class GroupStats {
  final String groupId;
  final String groupName;
  final int alarmsThisMonth;
  final int confirmed;
  final int snoozed;

  const GroupStats({
    required this.groupId,
    required this.groupName,
    this.alarmsThisMonth = 0,
    this.confirmed = 0,
    this.snoozed = 0,
  });

  factory GroupStats.fromJson(JsonMap json) => GroupStats(
        groupId: json['group_id'] as String,
        groupName: json['group_name'] as String,
        alarmsThisMonth: (json['alarms_this_month'] as num?)?.toInt() ?? 0,
        confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
        snoozed: (json['snoozed'] as num?)?.toInt() ?? 0,
      );

  JsonMap toJson() => {
        'group_id': groupId,
        'group_name': groupName,
        'alarms_this_month': alarmsThisMonth,
        'confirmed': confirmed,
        'snoozed': snoozed,
      };
}

/// Entrada del historial: una ocurrencia pasada de una alarma.
class HistoryEntry {
  final String occurrenceId;
  final String alarmId;
  final String title;
  final DateTime occurrenceAt;
  final bool isCreator;
  final PublicUserSummary creator;

  /// Estado de la ocurrencia (`triggered`, `cancelled`...).
  final AlarmStatus status;

  /// Mi respuesta (si fui destinatario).
  final ResponseStatus? myResponse;
  final int recipientCount;
  final int confirmedCount;
  final int snoozedCount;

  const HistoryEntry({
    required this.occurrenceId,
    required this.alarmId,
    required this.title,
    required this.occurrenceAt,
    required this.isCreator,
    required this.creator,
    required this.status,
    this.myResponse,
    this.recipientCount = 0,
    this.confirmedCount = 0,
    this.snoozedCount = 0,
  });

  factory HistoryEntry.fromJson(JsonMap json) => HistoryEntry(
        occurrenceId: json['occurrence_id'] as String,
        alarmId: json['alarm_id'] as String,
        title: json['title'] as String,
        occurrenceAt: parseRequiredDateTime(json['occurrence_at']),
        isCreator: json['is_creator'] as bool? ?? false,
        creator: PublicUserSummary.fromJson(json['creator'] as JsonMap),
        status: AlarmStatus.fromWire(json['status'] as String),
        myResponse: json['my_response'] == null
            ? null
            : ResponseStatus.fromWire(json['my_response'] as String),
        recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
        confirmedCount: (json['confirmed_count'] as num?)?.toInt() ?? 0,
        snoozedCount: (json['snoozed_count'] as num?)?.toInt() ?? 0,
      );

  JsonMap toJson() => {
        'occurrence_id': occurrenceId,
        'alarm_id': alarmId,
        'title': title,
        'occurrence_at': formatDateTime(occurrenceAt),
        'is_creator': isCreator,
        'creator': creator.toJson(),
        'status': status.wire,
        'my_response': myResponse?.wire,
        'recipient_count': recipientCount,
        'confirmed_count': confirmedCount,
        'snoozed_count': snoozedCount,
      };
}

/// Identificación mínima de un usuario en listados.
class PublicUserSummary {
  final String id;
  final String displayName;
  const PublicUserSummary({required this.id, required this.displayName});

  factory PublicUserSummary.fromJson(JsonMap json) => PublicUserSummary(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
      );

  JsonMap toJson() => {'id': id, 'display_name': displayName};
}
