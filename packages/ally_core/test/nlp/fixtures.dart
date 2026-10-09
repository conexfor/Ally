import 'package:ally_core/ally_core.dart';

/// Sábado 3 de octubre de 2026, 10:00.
final referenceNow = DateTime(2026, 10, 3, 10, 0);

const contacts = [
  DirectoryContact(userId: 'u-nicolas', username: 'nicolas', displayName: 'Nicolás'),
  DirectoryContact(userId: 'u-juan', username: 'juan', displayName: 'Juan Pérez'),
  DirectoryContact(userId: 'u-maria', username: 'maria', displayName: 'María López'),
  DirectoryContact(userId: 'u-pedro', username: 'pedro', displayName: 'Pedro'),
  DirectoryContact(userId: 'u-carlos-p', username: 'carlosp', displayName: 'Carlos Pérez'),
  DirectoryContact(userId: 'u-carlos-t', username: 'ctorres', displayName: 'Carlos Torres'),
  DirectoryContact(userId: 'u-carlos-g', username: 'cgomez', displayName: 'Carlos Gómez'),
];

const groups = [
  DirectoryGroup(groupId: 'g-dev', name: 'Equipo Desarrollo', memberCount: 4),
  DirectoryGroup(groupId: 'g-family', name: 'Familia', memberCount: 3),
  DirectoryGroup(groupId: 'g-uni', name: 'Universidad', memberCount: 12),
];

InterpretationContext context({
  DateTime? now,
  List<AlarmCandidate> alarms = const [],
  List<DirectoryGroup> groupList = groups,
}) =>
    InterpretationContext(
      now: now ?? referenceNow,
      timezone: 'America/Bogota',
      selfUserId: 'u-me',
      selfDisplayName: 'Yo',
      contacts: contacts,
      groups: groupList,
      alarms: alarms,
    );

final interpreter = RuleBasedCommandInterpreter();

InterpretationResult interpret(String text, {InterpretationContext? ctx}) =>
    interpreter.interpretSync(text, ctx ?? context());

LocalDate date(int y, int m, int d) => LocalDate(y, m, d);
LocalTime time(int h, int m) => LocalTime(h, m);

List<String?> recipientIds(InterpretationResult r) =>
    [for (final x in r.draft.recipients) x.id];
