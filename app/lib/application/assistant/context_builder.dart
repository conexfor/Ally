import 'package:ally_core/ally_core.dart';

import '../../data/local/local_store.dart';

/// Construye el contexto del intérprete con los datos locales, de modo que el
/// asistente funciona también sin conexión.
class InterpretationContextBuilder {
  final LocalStore store;
  InterpretationContextBuilder(this.store);

  Future<InterpretationContext> build({
    required String timezone,
    Set<String> ringingAlarmIds = const {},
    DateTime? now,
  }) async {
    final me = await store.me();
    final contacts = (await store.contacts()).where((c) => c.isAccepted);
    final groups = (await store.groups()).where((g) => g.myStatus == MemberStatus.active);
    final alarms = await store.alarms();
    final current = now ?? DateTime.now();

    LocalDateTime? local(DateTime? utc) => utc == null ? null : ZonedSchedule.toLocal(utc, timezone);

    return InterpretationContext(
      now: current,
      timezone: timezone,
      selfUserId: me?.id,
      selfDisplayName: me?.displayName,
      contacts: [
        for (final c in contacts)
          DirectoryContact(userId: c.user.id, username: c.user.username, displayName: c.user.displayName),
      ],
      groups: [
        for (final g in groups) DirectoryGroup(groupId: g.id, name: g.name, memberCount: g.activeMemberCount),
      ],
      alarms: [
        for (final a in alarms.where((a) => a.isActive || ringingAlarmIds.contains(a.id)))
          AlarmCandidate(
            alarmId: a.id,
            title: a.title,
            time: local(a.nextOccurrenceAt)?.time ?? a.localTime,
            nextOccurrence: local(a.nextOccurrenceAt),
            recipientNames: [for (final r in a.recipients) r.displayName],
            isOwn: a.creator.id == me?.id,
            isRinging: ringingAlarmIds.contains(a.id),
          ),
      ],
    );
  }
}
