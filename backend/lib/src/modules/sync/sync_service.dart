import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../alarms/alarms_repository.dart';
import '../contacts/contacts_service.dart';
import '../groups/groups_service.dart';
import '../notifications/notification_service.dart';

/// Sincronización incremental basada en `sync_version` (secuencia global).
///
/// - Alarmas, respuestas y notificaciones: solo lo que cambió desde el cursor
///   (incluidas "lápidas": alarmas eliminadas o rechazadas).
/// - Contactos y grupos: lista completa (son pocos y así reflejan bajas).
///
/// El cliente envía sus cambios locales con los endpoints REST normales
/// (las alarmas creadas sin conexión llevan un ID generado en el cliente,
/// por lo que reenviarlas es idempotente).
class SyncService {
  final Db db;
  final ContactsService contacts;
  final GroupsService groups;

  SyncService(this.db, this.contacts, this.groups);

  static const _alarmPage = 300;

  Future<SyncPayload> pull(String me, int cursor) async {
    final repo = AlarmsRepository(db);
    final (alarms, alarmsMax) = await repo.changedSince(me, cursor, limit: _alarmPage);
    final (responses, responsesMax) = await repo.responsesSince(me, cursor);
    final notificationRows = await db.query(
      'SELECT $notificationColumns, n.sync_version FROM notifications n '
      'WHERE n.user_id = @me::uuid AND n.sync_version > @c ORDER BY n.sync_version LIMIT 200',
      {'me': me, 'c': cursor},
    );
    final notificationsMax =
        notificationRows.isEmpty ? cursor : notificationRows.last['sync_version'] as int;

    // Si una fuente devolvió una página completa, el cursor no puede pasar de
    // su último elemento (para no saltarse los siguientes).
    final caps = [
      if (alarms.length >= _alarmPage) alarmsMax,
      if (responses.length >= 1000) responsesMax,
      if (notificationRows.length >= 200) notificationsMax,
    ];
    final hasMore = caps.isNotEmpty;
    var next = [alarmsMax, responsesMax, notificationsMax].reduce((a, b) => a > b ? a : b);
    for (final cap in caps) {
      if (cap < next) next = cap;
    }
    return SyncPayload(
      cursor: next < cursor ? cursor : next,
      serverTime: DateTime.now().toUtc(),
      alarms: alarms,
      responses: responses,
      contacts: await contacts.list(me),
      groups: await groups.list(me),
      notifications: [for (final r in notificationRows) notificationFromRow(r)],
      fullResync: cursor == 0,
      hasMore: hasMore,
    );
  }
}
