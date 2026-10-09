import '../domain/enums.dart';
import '../domain/local_date_time.dart';
import '../domain/repeat_rule.dart';
import 'json.dart';
import 'user_dtos.dart';

/// Destinatario de una alarma (usuario, grupo o dispositivo).
class AlarmRecipient {
  final String id;
  final RecipientType recipientType;
  final String recipientId;
  final String displayName;

  /// Usuario que recibe la alarma (null para filas de tipo grupo).
  final String? userId;

  /// Grupo a través del cual se añadió este usuario.
  final String? sourceGroupId;
  final PermissionStatus permissionStatus;
  final ResponseStatus responseStatus;
  final DateTime? respondedAt;

  const AlarmRecipient({
    required this.id,
    required this.recipientType,
    required this.recipientId,
    required this.displayName,
    required this.permissionStatus,
    required this.responseStatus,
    this.userId,
    this.sourceGroupId,
    this.respondedAt,
  });

  factory AlarmRecipient.fromJson(JsonMap json) => AlarmRecipient(
        id: json['id'] as String,
        recipientType: RecipientType.fromWire(json['recipient_type'] as String),
        recipientId: json['recipient_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        userId: json['user_id'] as String?,
        sourceGroupId: json['source_group_id'] as String?,
        permissionStatus:
            PermissionStatus.fromWire(json['permission_status'] as String),
        responseStatus: ResponseStatus.fromWire(
            json['response_status'] as String? ?? 'no_response'),
        respondedAt: parseDateTime(json['responded_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'recipient_type': recipientType.wire,
        'recipient_id': recipientId,
        'display_name': displayName,
        'user_id': userId,
        'source_group_id': sourceGroupId,
        'permission_status': permissionStatus.wire,
        'response_status': responseStatus.wire,
        'responded_at': formatDateTime(respondedAt),
      };
}

class Alarm {
  final String id;
  final PublicUser creator;
  final String title;
  final String? message;

  /// Fecha y hora (de pared) de la primera ocurrencia.
  final LocalDate localDate;
  final LocalTime localTime;
  final String timezone;

  /// Primera ocurrencia en UTC.
  final DateTime scheduledAt;
  final RepeatRule? repeat;
  final TriggerType triggerType;
  final AlarmStatus status;
  final AlarmPriority priority;
  final String sound;
  final bool vibration;

  /// El creador permite que los destinatarios vean las respuestas de los demás.
  final bool shareResponses;

  /// Versión para control de concurrencia optimista.
  final int version;
  final List<AlarmRecipient> recipients;
  final DateTime? nextOccurrenceAt;

  /// Rutina (alarmas encadenadas) a la que pertenece, si alguna.
  final String? sequenceId;
  final String? sequenceName;
  final int? sequencePosition;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Alarm({
    required this.id,
    required this.creator,
    required this.title,
    required this.localDate,
    required this.localTime,
    required this.timezone,
    required this.scheduledAt,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.message,
    this.repeat,
    this.triggerType = TriggerType.time,
    this.sound = 'default',
    this.vibration = true,
    this.shareResponses = true,
    this.version = 1,
    this.recipients = const [],
    this.nextOccurrenceAt,
    this.deletedAt,
    this.sequenceId,
    this.sequenceName,
    this.sequencePosition,
  });

  LocalDateTime get start => localDate.at(localTime);
  bool get isDeleted => deletedAt != null;
  bool get isActive =>
      !isDeleted &&
      status != AlarmStatus.cancelled &&
      status != AlarmStatus.completed;

  /// Fila de destinatario del usuario indicado (si la tiene).
  AlarmRecipient? recipientFor(String userId) {
    for (final r in recipients) {
      if (r.recipientType == RecipientType.user && r.userId == userId) return r;
    }
    return null;
  }

  factory Alarm.fromJson(JsonMap json) => Alarm(
        id: json['id'] as String,
        creator: PublicUser.fromJson(json['creator'] as JsonMap),
        title: json['title'] as String,
        message: json['message'] as String?,
        localDate: LocalDate.parse(json['local_date'] as String),
        localTime: LocalTime.parse(json['local_time'] as String),
        timezone: json['timezone'] as String,
        scheduledAt: parseRequiredDateTime(json['scheduled_at']),
        repeat: json['repeat_rule'] == null
            ? null
            : RepeatRule.fromJson(json['repeat_rule'] as JsonMap),
        triggerType: TriggerType.fromWire(json['trigger_type'] as String? ?? 'time'),
        status: AlarmStatus.fromWire(json['status'] as String),
        priority: AlarmPriority.fromWire(json['priority'] as String? ?? 'normal'),
        sound: json['sound'] as String? ?? 'default',
        vibration: json['vibration'] as bool? ?? true,
        shareResponses: json['share_responses'] as bool? ?? true,
        version: (json['version'] as num?)?.toInt() ?? 1,
        recipients: parseList(json['recipients'], AlarmRecipient.fromJson),
        nextOccurrenceAt: parseDateTime(json['next_occurrence_at']),
        createdAt: parseRequiredDateTime(json['created_at']),
        updatedAt: parseRequiredDateTime(json['updated_at']),
        deletedAt: parseDateTime(json['deleted_at']),
        sequenceId: json['sequence_id'] as String?,
        sequenceName: json['sequence_name'] as String?,
        sequencePosition: (json['sequence_position'] as num?)?.toInt(),
      );

  JsonMap toJson() => {
        'id': id,
        'creator': creator.toJson(),
        'title': title,
        'message': message,
        'local_date': localDate.toString(),
        'local_time': localTime.toString(),
        'timezone': timezone,
        'scheduled_at': formatDateTime(scheduledAt),
        'repeat_rule': repeat?.toJson(),
        'trigger_type': triggerType.wire,
        'status': status.wire,
        'priority': priority.wire,
        'sound': sound,
        'vibration': vibration,
        'share_responses': shareResponses,
        'version': version,
        'recipients': [for (final r in recipients) r.toJson()],
        'next_occurrence_at': formatDateTime(nextOccurrenceAt),
        'created_at': formatDateTime(createdAt),
        'updated_at': formatDateTime(updatedAt),
        'deleted_at': formatDateTime(deletedAt),
        if (sequenceId != null) 'sequence_id': sequenceId,
        if (sequenceName != null) 'sequence_name': sequenceName,
        if (sequencePosition != null) 'sequence_position': sequencePosition,
      };
}

/// Respuesta de un usuario a una ocurrencia concreta.
class AlarmResponse {
  final String id;
  final String alarmId;
  final String userId;
  final DateTime occurrenceAt;
  final ResponseStatus response;
  final DateTime? snoozedUntil;
  final DateTime respondedAt;
  final String? deviceId;

  const AlarmResponse({
    required this.id,
    required this.alarmId,
    required this.userId,
    required this.occurrenceAt,
    required this.response,
    required this.respondedAt,
    this.snoozedUntil,
    this.deviceId,
  });

  factory AlarmResponse.fromJson(JsonMap json) => AlarmResponse(
        id: json['id'] as String,
        alarmId: json['alarm_id'] as String,
        userId: json['user_id'] as String,
        occurrenceAt: parseRequiredDateTime(json['occurrence_at']),
        response: ResponseStatus.fromWire(json['response'] as String),
        snoozedUntil: parseDateTime(json['snoozed_until']),
        respondedAt: parseRequiredDateTime(json['responded_at']),
        deviceId: json['device_id'] as String?,
      );

  JsonMap toJson() => {
        'id': id,
        'alarm_id': alarmId,
        'user_id': userId,
        'occurrence_at': formatDateTime(occurrenceAt),
        'response': response.wire,
        'snoozed_until': formatDateTime(snoozedUntil),
        'responded_at': formatDateTime(respondedAt),
        'device_id': deviceId,
      };
}

class RecipientInput {
  final RecipientType type;
  final String id;
  const RecipientInput(this.type, this.id);

  factory RecipientInput.fromJson(JsonMap json) => RecipientInput(
        RecipientType.fromWire(json['type'] as String),
        json['id'] as String,
      );

  JsonMap toJson() => {'type': type.wire, 'id': id};
}

/// Datos para crear o actualizar una alarma.
class AlarmInput {
  /// ID generado por el cliente (permite crear sin conexión e idempotencia).
  final String? id;
  final String title;
  final String? message;
  final LocalDate localDate;
  final LocalTime localTime;
  final String timezone;
  final RepeatRule? repeat;
  final AlarmPriority priority;
  final String sound;
  final bool vibration;
  final bool shareResponses;
  final List<RecipientInput> recipients;

  /// Versión sobre la que se hicieron los cambios (solo al actualizar).
  final int? baseVersion;

  const AlarmInput({
    required this.title,
    required this.localDate,
    required this.localTime,
    required this.timezone,
    this.id,
    this.message,
    this.repeat,
    this.priority = AlarmPriority.normal,
    this.sound = 'default',
    this.vibration = true,
    this.shareResponses = true,
    this.recipients = const [],
    this.baseVersion,
  });

  factory AlarmInput.fromJson(JsonMap json) => AlarmInput(
        id: json['id'] as String?,
        title: (json['title'] as String? ?? '').trim(),
        message: (json['message'] as String?)?.trim(),
        localDate: LocalDate.parse(json['local_date'] as String),
        localTime: LocalTime.parse(json['local_time'] as String),
        timezone: json['timezone'] as String,
        repeat: json['repeat_rule'] == null
            ? null
            : RepeatRule.fromJson(json['repeat_rule'] as JsonMap),
        priority: AlarmPriority.fromWire(json['priority'] as String? ?? 'normal'),
        sound: json['sound'] as String? ?? 'default',
        vibration: json['vibration'] as bool? ?? true,
        shareResponses: json['share_responses'] as bool? ?? true,
        recipients: parseList(json['recipients'], RecipientInput.fromJson),
        baseVersion: (json['base_version'] as num?)?.toInt(),
      );

  JsonMap toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'message': message,
        'local_date': localDate.toString(),
        'local_time': localTime.toString(),
        'timezone': timezone,
        'repeat_rule': repeat?.toJson(),
        'priority': priority.wire,
        'sound': sound,
        'vibration': vibration,
        'share_responses': shareResponses,
        'recipients': [for (final r in recipients) r.toJson()],
        if (baseVersion != null) 'base_version': baseVersion,
      };
}

/// Respuesta del destinatario a una ocurrencia (confirmar, posponer...).
class RespondInput {
  final DateTime occurrenceAt;
  final ResponseStatus response;
  final int? snoozeMinutes;
  final String? deviceId;

  const RespondInput({
    required this.occurrenceAt,
    required this.response,
    this.snoozeMinutes,
    this.deviceId,
  });

  factory RespondInput.fromJson(JsonMap json) => RespondInput(
        occurrenceAt: parseRequiredDateTime(json['occurrence_at']),
        response: ResponseStatus.fromWire(json['response'] as String),
        snoozeMinutes: (json['snooze_minutes'] as num?)?.toInt(),
        deviceId: json['device_id'] as String?,
      );

  JsonMap toJson() => {
        'occurrence_at': formatDateTime(occurrenceAt),
        'response': response.wire,
        if (snoozeMinutes != null) 'snooze_minutes': snoozeMinutes,
        if (deviceId != null) 'device_id': deviceId,
      };
}
