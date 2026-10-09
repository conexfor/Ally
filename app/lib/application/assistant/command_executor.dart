import 'package:ally_core/ally_core.dart';

import '../../data/local/local_store.dart';
import '../../data/repositories/alarm_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../../services/device_service.dart';

/// Resultado de ejecutar un comando confirmado.
class ExecutionResult {
  final String reply;

  /// Pantalla relacionada (p. ej. el detalle de la alarma creada).
  final String? route;
  final String? routeLabel;

  const ExecutionResult(this.reply, {this.route, this.routeLabel});
}

/// Ejecuta un [CommandDraft] ya confirmado usando los repositorios de la app
/// (los mismos que usan los formularios: no hay lógica duplicada).
class CommandExecutor {
  final AlarmRepository alarms;
  final SocialRepository social;
  final LocalStore store;

  CommandExecutor(this.alarms, this.social, this.store);

  Future<ExecutionResult> execute(CommandDraft draft, {Map<String, DateTime> ringingOccurrences = const {}}) =>
      switch (draft.intent) {
        CommandIntent.createAlarm => _create(draft),
        CommandIntent.editAlarm => _edit(draft),
        CommandIntent.deleteAlarm => _delete(draft),
        CommandIntent.cancelAlarm => _cancel(draft, ringingOccurrences),
        CommandIntent.snoozeAlarm => _snooze(draft, ringingOccurrences),
        CommandIntent.listAlarms => _list(draft),
        CommandIntent.createGroup => _createGroup(draft),
        CommandIntent.addMember => _addMembers(draft),
        CommandIntent.removeMember => _removeMembers(draft),
        CommandIntent.listContacts => _listContacts(),
        CommandIntent.listGroups => _listGroups(),
        CommandIntent.help => Future.value(const ExecutionResult(RuleBasedCommandInterpreter.helpText)),
        CommandIntent.unknown => Future.value(const ExecutionResult(RuleBasedCommandInterpreter.notUnderstoodText)),
      };

  /// Convierte el borrador del asistente en los datos de una alarma.
  static AlarmInput toAlarmInput(CommandDraft draft, {required String meId, required String timezone}) {
    final message = draft.message?.trim();
    final title = message == null || message.isEmpty
        ? 'Alarma'
        : (message.length > Validators.maxTitleLength
            ? '${message.substring(0, Validators.maxTitleLength - 1)}…'
            : message);
    return AlarmInput(
      title: title,
      message: message,
      localDate: draft.date!,
      localTime: draft.time!,
      timezone: timezone,
      repeat: draft.repeat,
      recipients: [
        for (final r in draft.recipients)
          switch (r.type) {
            ResolvedRecipientType.self => RecipientInput(RecipientType.user, meId),
            ResolvedRecipientType.user => RecipientInput(RecipientType.user, r.id!),
            ResolvedRecipientType.group => RecipientInput(RecipientType.group, r.id!),
          },
      ],
    );
  }

  Future<ExecutionResult> _create(CommandDraft draft) async {
    final me = (await store.me())!;
    final input = toAlarmInput(draft, meId: me.id, timezone: await DeviceService.currentTimezone());
    final outcome = await alarms.create(input);
    final pending = outcome.value.recipients
        .where((r) => r.permissionStatus == PermissionStatus.pending)
        .map((r) => r.displayName)
        .toList();
    final buffer = StringBuffer('Alarma creada ✅');
    if (pending.isNotEmpty) {
      buffer.write('\n${SpanishFormatter.joinList(pending)} '
          '${pending.length == 1 ? 'debe' : 'deben'} aceptarla.');
    }
    if (outcome.queued) buffer.write('\nSin conexión: se enviará en cuanto vuelva internet.');
    return ExecutionResult(
      buffer.toString(),
      route: '/alarms/${outcome.value.id}',
      routeLabel: 'Ver alarma',
    );
  }

  Future<Alarm> _target(CommandDraft draft) async {
    final id = draft.target?.alarmId;
    final alarm = id == null ? null : await store.alarm(id);
    if (alarm == null) throw StateError('Alarma no encontrada');
    return alarm;
  }

  Future<ExecutionResult> _edit(CommandDraft draft) async {
    final alarm = await _target(draft);
    var date = alarm.localDate;
    var time = alarm.localTime;
    if (draft.time != null) {
      // Se mantiene la fecha de la próxima ocurrencia si solo cambia la hora.
      final next = alarm.nextOccurrenceAt;
      if (next != null && alarm.repeat == null) {
        date = ZonedSchedule.toLocal(next, alarm.timezone).date;
      }
      time = draft.time!;
    }
    if (draft.date != null) date = draft.date!;
    final input = AlarmInput(
      title: draft.message ?? alarm.title,
      message: draft.message ?? alarm.message,
      localDate: date,
      localTime: time,
      timezone: alarm.timezone,
      repeat: draft.repeat ?? alarm.repeat,
      priority: alarm.priority,
      sound: alarm.sound,
      vibration: alarm.vibration,
      shareResponses: alarm.shareResponses,
      recipients: [
        for (final r in alarm.recipients.where((r) => r.sourceGroupId == null))
          RecipientInput(r.recipientType, r.recipientId),
      ],
    );
    final outcome = await alarms.update(alarm, input);
    return ExecutionResult(
      outcome.queued ? 'Cambios guardados. Se enviarán cuando haya conexión.' : 'Alarma modificada ✅',
      route: '/alarms/${alarm.id}',
      routeLabel: 'Ver alarma',
    );
  }

  Future<ExecutionResult> _delete(CommandDraft draft) async {
    final alarm = await _target(draft);
    final outcome = await alarms.delete(alarm);
    return ExecutionResult(outcome.queued
        ? 'Alarma eliminada. Se avisará a los demás cuando haya conexión.'
        : 'Alarma «${alarm.title}» eliminada.');
  }

  Future<ExecutionResult> _cancel(CommandDraft draft, Map<String, DateTime> ringing) async {
    final alarm = await _target(draft);
    final occurrence = ringing[alarm.id];
    if (occurrence != null) {
      await alarms.respond(alarm, occurrence, ResponseStatus.dismissed);
      return ExecutionResult('Alarma «${alarm.title}» detenida.');
    }
    final outcome = await alarms.cancelNext(alarm);
    return ExecutionResult(
      outcome.value.repeat == null
          ? 'Alarma «${alarm.title}» desactivada.'
          : 'La próxima vez de «${alarm.title}» no sonará.',
    );
  }

  Future<ExecutionResult> _snooze(CommandDraft draft, Map<String, DateTime> ringing) async {
    final alarm = await _target(draft);
    final occurrence = ringing[alarm.id] ?? alarm.nextOccurrenceAt;
    if (occurrence == null) return const ExecutionResult('Esa alarma no tiene próximas ocurrencias.');
    final minutes = draft.snoozeMinutes!;
    await alarms.respond(alarm, occurrence, ResponseStatus.snoozed, snoozeMinutes: minutes);
    return ExecutionResult('Pospuesta ${SpanishFormatter.duration(minutes)} 😴');
  }

  Future<ExecutionResult> _list(CommandDraft draft) async {
    final timezone = await DeviceService.currentTimezone();
    final now = DateTime.now().toUtc();
    final today = ZonedSchedule.toLocal(now, timezone).date;
    final from = draft.date == null ? now : ZonedSchedule.toUtc(draft.date!.at(LocalTime(0, 0)), timezone);
    final to = draft.date == null
        ? now.add(const Duration(days: 7))
        : ZonedSchedule.toUtc(draft.date!.addDays(1).at(LocalTime(0, 0)), timezone);

    final items = <(DateTime, Alarm)>[];
    for (final alarm in await store.alarms()) {
      if (!alarm.isActive) continue;
      final occurrences = ZonedSchedule.occurrencesBetweenUtc(
        start: alarm.start,
        rule: alarm.repeat,
        timezone: alarm.timezone,
        fromUtc: from.isBefore(now) ? now : from,
        untilUtc: to,
        limit: 10,
      );
      for (final o in occurrences) {
        final local = ZonedSchedule.toLocal(o, timezone);
        if (draft.period != null && !_inPeriod(local.time, draft.period!)) continue;
        items.add((o, alarm));
      }
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));

    final when = draft.date == null
        ? 'en los próximos 7 días'
        : SpanishFormatter.date(draft.date!, today).toLowerCase() == 'hoy'
            ? 'hoy'
            : 'para ${SpanishFormatter.date(draft.date!, today).toLowerCase()}';
    if (items.isEmpty) return ExecutionResult('No tienes alarmas $when.');

    final buffer = StringBuffer(items.length == 1 ? 'Tienes 1 alarma $when:' : 'Tienes ${items.length} alarmas $when:');
    for (final (at, alarm) in items.take(15)) {
      final local = ZonedSchedule.toLocal(at, timezone);
      final day = draft.date == null ? '${SpanishFormatter.date(local.date, today)} ' : '';
      buffer.write('\n• $day${SpanishFormatter.time(local.time)} — ${alarm.title}');
    }
    if (items.length > 15) buffer.write('\n… y ${items.length - 15} más.');
    return ExecutionResult(buffer.toString(), route: '/alarms', routeLabel: 'Ver todas');
  }

  static bool _inPeriod(LocalTime t, DayPeriod period) => switch (period) {
        DayPeriod.earlyMorning => t.hour < 6,
        DayPeriod.morning => t.hour >= 5 && t.hour < 12,
        DayPeriod.noon => t.hour >= 12 && t.hour < 14,
        DayPeriod.afternoon => t.hour >= 12 && t.hour < 19,
        DayPeriod.night => t.hour >= 19 || t.hour < 5,
      };

  Future<ExecutionResult> _createGroup(CommandDraft draft) async {
    final group = await social.createGroup(
      draft.groupName!,
      memberIds: [for (final m in draft.members) m.id!],
    );
    final invited = draft.members.isEmpty
        ? ''
        : '\nInvité a ${SpanishFormatter.joinList([for (final m in draft.members) m.displayName])}.';
    return ExecutionResult('Grupo «${group.name}» creado ✅$invited',
        route: '/groups/${group.id}', routeLabel: 'Ver grupo');
  }

  Future<ExecutionResult> _addMembers(CommandDraft draft) async {
    final group = await social.addMembers(draft.groupId!, [for (final m in draft.members) m.id!]);
    final names = SpanishFormatter.joinList([for (final m in draft.members) m.displayName]);
    return ExecutionResult('Invité a $names al grupo «${group.name}».',
        route: '/groups/${group.id}', routeLabel: 'Ver grupo');
  }

  Future<ExecutionResult> _removeMembers(CommandDraft draft) async {
    for (final m in draft.members) {
      await social.removeMember(draft.groupId!, m.id!);
    }
    final names = SpanishFormatter.joinList([for (final m in draft.members) m.displayName]);
    return ExecutionResult('Quité a $names del grupo «${draft.groupName}».');
  }

  Future<ExecutionResult> _listContacts() async {
    final contacts = (await store.contacts()).where((c) => c.isAccepted).toList();
    if (contacts.isEmpty) {
      return const ExecutionResult('Aún no tienes contactos. Agrega a alguien desde Personas.',
          route: '/contacts/add', routeLabel: 'Agregar contacto');
    }
    final lines = [for (final c in contacts) '• ${c.user.displayName} (@${c.user.username})'];
    return ExecutionResult('Tus contactos:\n${lines.join('\n')}', route: '/people', routeLabel: 'Ver contactos');
  }

  Future<ExecutionResult> _listGroups() async {
    final groups = (await store.groups()).where((g) => g.myStatus == MemberStatus.active).toList();
    if (groups.isEmpty) {
      return const ExecutionResult('No perteneces a ningún grupo. Prueba: «Crea un grupo llamado Familia».');
    }
    final lines = [for (final g in groups) '• ${g.name} (${g.activeMemberCount} miembros)'];
    return ExecutionResult('Tus grupos:\n${lines.join('\n')}', route: '/people?tab=groups', routeLabel: 'Ver grupos');
  }
}
