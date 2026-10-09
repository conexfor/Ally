import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../alarms/alarms_repository.dart';
import '../contacts/contacts_service.dart';
import '../groups/groups_service.dart';
import '../users/users_repository.dart';

/// Expone el intérprete basado en reglas (`POST /api/parser/parse`).
///
/// El contexto (contactos, grupos, alarmas, zona horaria) se construye en el
/// servidor a partir de los datos del usuario: el cliente no puede inyectar
/// destinatarios que no sean sus contactos.
class ParserService {
  final Db db;
  final ContactsService contacts;
  final GroupsService groups;
  final CommandInterpreter interpreter;

  ParserService(this.db, this.contacts, this.groups, {CommandInterpreter? interpreter})
      : interpreter = interpreter ?? RuleBasedCommandInterpreter();

  static const maxTextLength = 500;

  /// - `{text}`: interpreta un texto nuevo.
  /// - `{pending, option_id}`: aplica una opción de la aclaración pendiente.
  /// - `{pending, text}`: responde con texto a la aclaración pendiente.
  Future<InterpretationResult> parse(String me, JsonMap body) async {
    final text = (body['text'] as String?)?.trim();
    if (text != null && text.length > maxTextLength) {
      throw const ApiException.badRequest('El mensaje es demasiado largo.');
    }
    final ctx = await buildContext(me, timezone: body['timezone'] as String?);
    final pendingJson = body['pending'];
    if (pendingJson is Map<String, dynamic>) {
      final InterpretationResult pending;
      try {
        pending = InterpretationResult.fromJson(pendingJson);
      } catch (_) {
        throw const ApiException.badRequest('La conversación pendiente no es válida.');
      }
      final optionId = body['option_id'] as String?;
      if (optionId != null) {
        final option = pending.pendingClarification?.options
            .where((o) => o.id == optionId)
            .firstOrNull;
        if (option == null) throw const ApiException.badRequest('Esa opción ya no está disponible.');
        return interpreter.applyOption(pending.draft, option, ctx);
      }
      if (text != null && text.isNotEmpty) return interpreter.answer(pending, text, ctx);
    }
    if (text == null || text.isEmpty) {
      throw const ApiException.badRequest('Escribe lo que quieres hacer.');
    }
    return interpreter.interpret(text, ctx);
  }

  Future<InterpretationContext> buildContext(String me, {String? timezone}) async {
    final user = await UsersRepository(db).findById(me);
    if (user == null) throw const ApiException.unauthorized();
    final tz = timezone != null && ZonedSchedule.isValidTimezone(timezone) ? timezone : user.timezone;
    final nowUtc = DateTime.now().toUtc();
    final nowLocal = ZonedSchedule.toLocal(nowUtc, tz);

    final contactList = await contacts.accepted(me);
    final groupList = (await groups.list(me)).where((g) => g.myStatus == MemberStatus.active);
    final alarms = await AlarmsRepository(db).listVisible(me);
    final ringing = {
      for (final r in await db.query(
        '''
        SELECT o.alarm_id::text AS id FROM alarm_occurrences o
        JOIN alarm_recipients r ON r.alarm_id = o.alarm_id AND r.user_id = @me::uuid
        WHERE o.scheduled_for BETWEEN @from AND @now
          AND NOT EXISTS (SELECT 1 FROM alarm_responses x WHERE x.occurrence_id = o.id AND x.user_id = @me::uuid)
        ''',
        {'me': me, 'from': nowUtc.subtract(const Duration(minutes: 15)), 'now': nowUtc},
      ))
        r['id'] as String,
    };

    return InterpretationContext(
      now: DateTime(
        nowLocal.date.year,
        nowLocal.date.month,
        nowLocal.date.day,
        nowLocal.time.hour,
        nowLocal.time.minute,
      ),
      timezone: tz,
      selfUserId: me,
      selfDisplayName: user.displayName,
      contacts: [
        for (final c in contactList)
          DirectoryContact(
            userId: c.user.id,
            username: c.user.username,
            displayName: c.user.displayName,
          ),
      ],
      groups: [
        for (final g in groupList)
          DirectoryGroup(groupId: g.id, name: g.name, memberCount: g.activeMemberCount),
      ],
      alarms: [
        for (final a in alarms)
          AlarmCandidate(
            alarmId: a.id,
            title: a.title,
            time: a.nextOccurrenceAt == null
                ? a.localTime
                : ZonedSchedule.toLocal(a.nextOccurrenceAt!, tz).time,
            nextOccurrence: a.nextOccurrenceAt == null
                ? null
                : ZonedSchedule.toLocal(a.nextOccurrenceAt!, tz),
            recipientNames: [for (final r in a.recipients) r.displayName],
            isOwn: a.creator.id == me,
            isRinging: ringing.contains(a.id),
          ),
      ],
    );
  }
}
