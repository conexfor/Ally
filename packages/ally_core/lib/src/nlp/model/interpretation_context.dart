import '../../domain/local_date_time.dart';

/// Contacto con el que el usuario puede compartir alarmas.
class DirectoryContact {
  final String userId;
  final String username;
  final String displayName;

  const DirectoryContact({
    required this.userId,
    required this.username,
    required this.displayName,
  });
}

/// Grupo al que pertenece el usuario.
class DirectoryGroup {
  final String groupId;
  final String name;
  final int memberCount;

  const DirectoryGroup({
    required this.groupId,
    required this.name,
    this.memberCount = 0,
  });
}

/// Resumen de una alarma existente, usado para resolver referencias como
/// "cancela la alarma de las 3".
class AlarmCandidate {
  final String alarmId;
  final String title;

  /// Próxima ocurrencia (hora local) o `null` si ya no volverá a sonar.
  final LocalDateTime? nextOccurrence;

  /// Hora configurada (para alarmas recurrentes sin ocurrencia futura).
  final LocalTime time;
  final List<String> recipientNames;

  /// El usuario es quien la creó (solo el creador puede editarla/eliminarla).
  final bool isOwn;

  /// Está sonando o sonó hace poco (candidata natural a "posponer").
  final bool isRinging;

  const AlarmCandidate({
    required this.alarmId,
    required this.title,
    required this.time,
    this.nextOccurrence,
    this.recipientNames = const [],
    this.isOwn = true,
    this.isRinging = false,
  });
}

/// Todo lo que el intérprete necesita saber del usuario y su entorno.
class InterpretationContext {
  /// Hora de pared actual en la zona horaria del usuario.
  final DateTime now;
  final String timezone;
  final String? selfUserId;
  final String? selfDisplayName;
  final List<DirectoryContact> contacts;
  final List<DirectoryGroup> groups;
  final List<AlarmCandidate> alarms;

  const InterpretationContext({
    required this.now,
    this.timezone = 'UTC',
    this.selfUserId,
    this.selfDisplayName,
    this.contacts = const [],
    this.groups = const [],
    this.alarms = const [],
  });

  LocalDate get today => LocalDate.fromDateTime(now);
  LocalDateTime get nowLocal => LocalDateTime.fromDateTime(now);
}
