import '../../domain/local_date_time.dart';
import '../../domain/repeat_rule.dart';
import '../lexicon/time_lexicon.dart';
import 'command_intent.dart';

enum ResolvedRecipientType {
  user('user'),
  group('group'),
  self('self');

  const ResolvedRecipientType(this.wire);
  final String wire;
  static ResolvedRecipientType fromWire(String w) =>
      values.firstWhere((v) => v.wire == w);
}

/// Destinatario ya identificado.
class ResolvedRecipient {
  final ResolvedRecipientType type;

  /// ID de usuario o grupo (null para [ResolvedRecipientType.self] sin sesión).
  final String? id;
  final String displayName;
  final String? username;

  const ResolvedRecipient({
    required this.type,
    required this.displayName,
    this.id,
    this.username,
  });

  factory ResolvedRecipient.fromJson(Map<String, dynamic> json) =>
      ResolvedRecipient(
        type: ResolvedRecipientType.fromWire(json['type'] as String),
        id: json['id'] as String?,
        displayName: json['display_name'] as String,
        username: json['username'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'id': id,
        'display_name': displayName,
        if (username != null) 'username': username,
      };

  bool sameAs(ResolvedRecipient other) =>
      type == other.type && id == other.id;
}

/// Referencia a una alarma existente ("la alarma de las 3 de mañana").
class AlarmTarget {
  final LocalDate? date;

  /// Horas posibles (p. ej. 05:00 y 17:00 si no se indicó AM/PM).
  final List<LocalTime> times;

  /// Alarma concreta, una vez identificada.
  final String? alarmId;
  final String? alarmTitle;

  const AlarmTarget({
    this.date,
    this.times = const [],
    this.alarmId,
    this.alarmTitle,
  });

  bool get isEmpty => date == null && times.isEmpty && alarmId == null;

  AlarmTarget withAlarm(String id, String title) =>
      AlarmTarget(date: date, times: times, alarmId: id, alarmTitle: title);

  factory AlarmTarget.fromJson(Map<String, dynamic> json) => AlarmTarget(
        date: json['date'] == null ? null : LocalDate.parse(json['date'] as String),
        times: [
          for (final t in (json['times'] as List? ?? const []))
            LocalTime.parse(t as String),
        ],
        alarmId: json['alarm_id'] as String?,
        alarmTitle: json['alarm_title'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date': date?.toString(),
        'times': [for (final t in times) t.toString()],
        'alarm_id': alarmId,
        'alarm_title': alarmTitle,
      };
}

/// Comando interpretado y resuelto, listo para validar/confirmar/ejecutar.
///
/// Es serializable para poder guardarlo en el historial del chat mientras se
/// esperan aclaraciones del usuario.
class CommandDraft {
  static const _unset = Object();

  final CommandIntent intent;
  final String originalText;

  final LocalDate? date;
  final LocalTime? time;

  /// La fecha no la dijo el usuario: se dedujo (hoy/mañana).
  final bool dateInferred;

  /// Opciones de fecha/hora cuando no se pudo decidir AM/PM.
  final List<LocalDateTime> timeOptions;

  /// Franja del día mencionada (ayuda a resolver horas y filtra consultas).
  final DayPeriod? period;
  final RepeatRule? repeat;

  final List<ResolvedRecipient> recipients;

  /// Nombres mencionados que aún no se pudieron identificar.
  final List<String> unresolvedRecipients;

  final String? message;
  final int? snoozeMinutes;
  final AlarmTarget? target;

  // Comandos de grupos
  final String? groupId;
  final String? groupName;
  final List<ResolvedRecipient> members;
  final List<String> unresolvedMembers;

  /// Palabras que el parser no entendió.
  final List<String> unrecognizedWords;

  /// El intent se dedujo (no había verbo explícito).
  final bool intentInferred;

  /// Se mencionó una fecha que no existe (p. ej. 31 de febrero).
  final bool invalidDate;

  const CommandDraft({
    required this.intent,
    required this.originalText,
    this.date,
    this.time,
    this.dateInferred = false,
    this.timeOptions = const [],
    this.period,
    this.repeat,
    this.recipients = const [],
    this.unresolvedRecipients = const [],
    this.message,
    this.snoozeMinutes,
    this.target,
    this.groupId,
    this.groupName,
    this.members = const [],
    this.unresolvedMembers = const [],
    this.unrecognizedWords = const [],
    this.intentInferred = false,
    this.invalidDate = false,
  });

  /// Fecha y hora resueltas (si ambas existen).
  LocalDateTime? get scheduledAt =>
      date != null && time != null ? date!.at(time!) : null;

  /// Comprensión parcial: quedaron palabras sin entender o el intent se dedujo.
  bool get isPartial => unrecognizedWords.length >= 2 || intentInferred;

  CommandDraft copyWith({
    CommandIntent? intent,
    Object? date = _unset,
    Object? time = _unset,
    bool? dateInferred,
    List<LocalDateTime>? timeOptions,
    Object? period = _unset,
    Object? repeat = _unset,
    List<ResolvedRecipient>? recipients,
    List<String>? unresolvedRecipients,
    Object? message = _unset,
    Object? snoozeMinutes = _unset,
    Object? target = _unset,
    Object? groupId = _unset,
    Object? groupName = _unset,
    List<ResolvedRecipient>? members,
    List<String>? unresolvedMembers,
    List<String>? unrecognizedWords,
    bool? intentInferred,
    bool? invalidDate,
  }) =>
      CommandDraft(
        intent: intent ?? this.intent,
        originalText: originalText,
        date: date == _unset ? this.date : date as LocalDate?,
        time: time == _unset ? this.time : time as LocalTime?,
        dateInferred: dateInferred ?? this.dateInferred,
        timeOptions: timeOptions ?? this.timeOptions,
        period: period == _unset ? this.period : period as DayPeriod?,
        repeat: repeat == _unset ? this.repeat : repeat as RepeatRule?,
        recipients: recipients ?? this.recipients,
        unresolvedRecipients: unresolvedRecipients ?? this.unresolvedRecipients,
        message: message == _unset ? this.message : message as String?,
        snoozeMinutes:
            snoozeMinutes == _unset ? this.snoozeMinutes : snoozeMinutes as int?,
        target: target == _unset ? this.target : target as AlarmTarget?,
        groupId: groupId == _unset ? this.groupId : groupId as String?,
        groupName: groupName == _unset ? this.groupName : groupName as String?,
        members: members ?? this.members,
        unresolvedMembers: unresolvedMembers ?? this.unresolvedMembers,
        unrecognizedWords: unrecognizedWords ?? this.unrecognizedWords,
        intentInferred: intentInferred ?? this.intentInferred,
        invalidDate: invalidDate ?? this.invalidDate,
      );

  factory CommandDraft.fromJson(Map<String, dynamic> json) => CommandDraft(
        intent: CommandIntent.fromCode(json['intent'] as String),
        originalText: json['original_text'] as String? ?? '',
        date: json['date'] == null ? null : LocalDate.parse(json['date'] as String),
        time: json['time'] == null ? null : LocalTime.parse(json['time'] as String),
        dateInferred: json['date_inferred'] as bool? ?? false,
        timeOptions: [
          for (final o in (json['time_options'] as List? ?? const []))
            LocalDateTime.parse(o as String),
        ],
        period: json['period'] == null
            ? null
            : DayPeriod.fromWire(json['period'] as String),
        repeat: json['repeat'] == null
            ? null
            : RepeatRule.fromJson(json['repeat'] as Map<String, dynamic>),
        recipients: [
          for (final r in (json['recipients'] as List? ?? const []))
            ResolvedRecipient.fromJson(r as Map<String, dynamic>),
        ],
        unresolvedRecipients:
            List<String>.from(json['unresolved_recipients'] as List? ?? const []),
        message: json['message'] as String?,
        snoozeMinutes: (json['snooze_minutes'] as num?)?.toInt(),
        target: json['target'] == null
            ? null
            : AlarmTarget.fromJson(json['target'] as Map<String, dynamic>),
        groupId: json['group_id'] as String?,
        groupName: json['group_name'] as String?,
        members: [
          for (final r in (json['members'] as List? ?? const []))
            ResolvedRecipient.fromJson(r as Map<String, dynamic>),
        ],
        unresolvedMembers:
            List<String>.from(json['unresolved_members'] as List? ?? const []),
        unrecognizedWords:
            List<String>.from(json['unrecognized_words'] as List? ?? const []),
        intentInferred: json['intent_inferred'] as bool? ?? false,
        invalidDate: json['invalid_date'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'intent': intent.code,
        'action': intent.code.toLowerCase(),
        'original_text': originalText,
        'date': date?.toString(),
        'time': time?.toString(),
        'date_inferred': dateInferred,
        if (timeOptions.isNotEmpty)
          'time_options': [for (final o in timeOptions) o.toString()],
        if (period != null) 'period': period!.wire,
        'repeat': repeat?.toJson(),
        'recipients': [for (final r in recipients) r.toJson()],
        if (unresolvedRecipients.isNotEmpty)
          'unresolved_recipients': unresolvedRecipients,
        'message': message,
        if (snoozeMinutes != null) 'snooze_minutes': snoozeMinutes,
        if (target != null) 'target': target!.toJson(),
        if (groupId != null) 'group_id': groupId,
        if (groupName != null) 'group_name': groupName,
        if (members.isNotEmpty) 'members': [for (final m in members) m.toJson()],
        if (unresolvedMembers.isNotEmpty) 'unresolved_members': unresolvedMembers,
        if (unrecognizedWords.isNotEmpty) 'unrecognized_words': unrecognizedWords,
        if (intentInferred) 'intent_inferred': true,
        if (invalidDate) 'invalid_date': true,
      };
}
