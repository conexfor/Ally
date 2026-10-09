import '../domain/local_date_time.dart';
import '../domain/repeat_rule.dart';
import 'alarm_dtos.dart';
import 'json.dart';

/// Paso de una rutina (cada paso es una alarma).
class SequenceStepInput {
  final String title;
  final String? message;
  final LocalTime localTime;

  const SequenceStepInput({required this.title, required this.localTime, this.message});

  factory SequenceStepInput.fromJson(JsonMap json) => SequenceStepInput(
        title: (json['title'] as String? ?? '').trim(),
        message: (json['message'] as String?)?.trim(),
        localTime: LocalTime.parse(json['local_time'] as String),
      );

  JsonMap toJson() => {'title': title, 'message': message, 'local_time': localTime.toString()};
}

/// Datos para crear una rutina: 07:00 Despertar → 07:15 Prepararse → ...
class SequenceInput {
  final String name;
  final LocalDate localDate;
  final String timezone;
  final RepeatRule? repeat;
  final List<RecipientInput> recipients;
  final List<SequenceStepInput> steps;

  const SequenceInput({
    required this.name,
    required this.localDate,
    required this.timezone,
    required this.steps,
    this.repeat,
    this.recipients = const [],
  });

  factory SequenceInput.fromJson(JsonMap json) => SequenceInput(
        name: (json['name'] as String? ?? '').trim(),
        localDate: LocalDate.parse(json['local_date'] as String),
        timezone: json['timezone'] as String,
        repeat: json['repeat_rule'] == null ? null : RepeatRule.fromJson(json['repeat_rule'] as JsonMap),
        recipients: parseList(json['recipients'], RecipientInput.fromJson),
        steps: parseList(json['steps'], SequenceStepInput.fromJson),
      );

  JsonMap toJson() => {
        'name': name,
        'local_date': localDate.toString(),
        'timezone': timezone,
        'repeat_rule': repeat?.toJson(),
        'recipients': [for (final r in recipients) r.toJson()],
        'steps': [for (final s in steps) s.toJson()],
      };
}

class AlarmSequenceStep {
  final String alarmId;
  final int position;
  final int offsetMinutes;
  final String title;
  final LocalTime localTime;

  const AlarmSequenceStep({
    required this.alarmId,
    required this.position,
    required this.offsetMinutes,
    required this.title,
    required this.localTime,
  });

  factory AlarmSequenceStep.fromJson(JsonMap json) => AlarmSequenceStep(
        alarmId: json['alarm_id'] as String,
        position: (json['position'] as num).toInt(),
        offsetMinutes: (json['offset_minutes'] as num?)?.toInt() ?? 0,
        title: json['title'] as String,
        localTime: LocalTime.parse(json['local_time'] as String),
      );

  JsonMap toJson() => {
        'alarm_id': alarmId,
        'position': position,
        'offset_minutes': offsetMinutes,
        'title': title,
        'local_time': localTime.toString(),
      };
}

class AlarmSequence {
  final String id;
  final String name;
  final List<AlarmSequenceStep> steps;
  final DateTime createdAt;

  const AlarmSequence({required this.id, required this.name, required this.steps, required this.createdAt});

  factory AlarmSequence.fromJson(JsonMap json) => AlarmSequence(
        id: json['id'] as String,
        name: json['name'] as String,
        steps: parseList(json['steps'], AlarmSequenceStep.fromJson),
        createdAt: parseRequiredDateTime(json['created_at']),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'steps': [for (final s in steps) s.toJson()],
        'created_at': formatDateTime(createdAt),
      };
}
