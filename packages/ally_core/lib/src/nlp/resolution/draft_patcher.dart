import '../../domain/local_date_time.dart';
import '../model/command_draft.dart';

/// Claves admitidas en el `patch` de una opción de aclaración.
abstract final class PatchKeys {
  static const date = 'date';
  static const time = 'time';
  static const addRecipient = 'add_recipient';
  static const resolveRecipient = 'resolve_recipient';
  static const targetAlarmId = 'target_alarm_id';
  static const targetAlarmTitle = 'target_alarm_title';
  static const snoozeMinutes = 'snooze_minutes';
  static const groupId = 'group_id';
  static const groupName = 'group_name';
  static const addMember = 'add_member';
  static const resolveMember = 'resolve_member';
  static const message = 'message';
}

/// Aplica la respuesta del usuario (una opción elegida) a un borrador.
class DraftPatcher {
  const DraftPatcher();

  CommandDraft apply(CommandDraft draft, Map<String, dynamic> patch) {
    var result = draft;

    if (patch.containsKey(PatchKeys.time) || patch.containsKey(PatchKeys.date)) {
      result = result.copyWith(
        time: patch[PatchKeys.time] == null
            ? result.time
            : LocalTime.parse(patch[PatchKeys.time] as String),
        date: patch[PatchKeys.date] == null
            ? result.date
            : LocalDate.parse(patch[PatchKeys.date] as String),
        dateInferred: patch[PatchKeys.date] == null ? result.dateInferred : false,
        timeOptions: const [],
      );
    }

    if (patch[PatchKeys.addRecipient] case final Map<String, dynamic> r) {
      final recipient = ResolvedRecipient.fromJson(r);
      if (!result.recipients.any((x) => x.sameAs(recipient))) {
        result = result.copyWith(recipients: [...result.recipients, recipient]);
      }
    }
    if (patch[PatchKeys.resolveRecipient] case final String raw) {
      result = result.copyWith(
        unresolvedRecipients: [...result.unresolvedRecipients]..remove(raw),
      );
    }

    if (patch[PatchKeys.targetAlarmId] case final String id) {
      result = result.copyWith(
        target: (result.target ?? const AlarmTarget())
            .withAlarm(id, patch[PatchKeys.targetAlarmTitle] as String? ?? ''),
      );
    }

    if (patch[PatchKeys.snoozeMinutes] case final num minutes) {
      result = result.copyWith(snoozeMinutes: minutes.toInt());
    }

    if (patch[PatchKeys.groupId] case final String id) {
      result = result.copyWith(
        groupId: id,
        groupName: patch[PatchKeys.groupName] as String? ?? result.groupName,
      );
    } else if (patch[PatchKeys.groupName] case final String name) {
      result = result.copyWith(groupName: name);
    }

    if (patch[PatchKeys.addMember] case final Map<String, dynamic> m) {
      final member = ResolvedRecipient.fromJson(m);
      if (!result.members.any((x) => x.sameAs(member))) {
        result = result.copyWith(members: [...result.members, member]);
      }
    }
    if (patch[PatchKeys.resolveMember] case final String raw) {
      result = result.copyWith(
        unresolvedMembers: [...result.unresolvedMembers]..remove(raw),
      );
    }

    if (patch[PatchKeys.message] case final String message) {
      result = result.copyWith(message: message);
    }

    return result;
  }
}
