import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../../security/token_service.dart';
import '../notifications/notification_service.dart';
import '../users/users_repository.dart';

/// A quién se envía una solicitud de conexión.
class ConnectionTarget {
  final String? userId;
  final String? username;
  final String? email;
  final String? phone;

  const ConnectionTarget({this.userId, this.username, this.email, this.phone});

  factory ConnectionTarget.fromJson(JsonMap json) => ConnectionTarget(
        userId: json['user_id'] as String?,
        username: json['username'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );
}

class ContactsService {
  final Db db;
  final NotificationService notifications;

  ContactsService(this.db, this.notifications);

  static const _rejectionCooldown = Duration(days: 7);
  static const _codeValidity = Duration(days: 7);

  String _contactsSql(String extraWhere) => '''
    SELECT c.id::text AS connection_id, c.status, c.created_at, c.updated_at,
           CASE WHEN c.requester_id = @me::uuid THEN 'outgoing' ELSE 'incoming' END AS direction,
           ${publicUserColumns('o')},
           mine.allow_alarms AS mine_allow, mine.auto_accept AS mine_auto, mine.share_response_status AS mine_share,
           theirs.allow_alarms AS theirs_allow, theirs.auto_accept AS theirs_auto,
           theirs.share_response_status AS theirs_share
    FROM connections c
    JOIN users o ON o.id = CASE WHEN c.requester_id = @me::uuid THEN c.addressee_id ELSE c.requester_id END
    LEFT JOIN connection_permissions mine ON mine.connection_id = c.id AND mine.owner_id = @me::uuid
    LEFT JOIN connection_permissions theirs ON theirs.connection_id = c.id AND theirs.owner_id = o.id
    WHERE (c.requester_id = @me::uuid OR c.addressee_id = @me::uuid)
      AND o.deleted_at IS NULL
      AND c.status <> 'rejected'
      AND NOT (c.status = 'blocked' AND c.blocked_by <> @me::uuid)
      $extraWhere
  ''';

  static Contact contactFromRow(Row r) => Contact(
        connectionId: r['connection_id'] as String,
        status: ConnectionStatus.fromWire(r['status'] as String),
        direction: ConnectionDirection.fromWire(r['direction'] as String),
        user: publicUserFromRow(r),
        grantedByMe: ConnectionPermissions(
          allowAlarms: r['mine_allow'] as bool? ?? true,
          autoAccept: r['mine_auto'] as bool? ?? false,
          shareResponseStatus: r['mine_share'] as bool? ?? true,
        ),
        grantedToMe: ConnectionPermissions(
          allowAlarms: r['theirs_allow'] as bool? ?? true,
          autoAccept: r['theirs_auto'] as bool? ?? false,
          shareResponseStatus: r['theirs_share'] as bool? ?? true,
        ),
        createdAt: r['created_at'] as DateTime,
        updatedAt: r['updated_at'] as DateTime,
      );

  Future<List<Contact>> list(String me) async {
    final rows = await db.query(_contactsSql('ORDER BY o.display_name'), {'me': me});
    return [for (final r in rows) contactFromRow(r)];
  }

  Future<Contact> get(String me, String connectionId) async {
    final row = await db.one(
      _contactsSql('AND c.id = @id::uuid'),
      {'me': me, 'id': connectionId},
    );
    if (row == null) throw const ApiException.notFound('No encontramos ese contacto.');
    return contactFromRow(row);
  }

  /// Contactos aceptados (para resolver nombres en el asistente).
  Future<List<Contact>> accepted(String me) async =>
      (await list(me)).where((c) => c.isAccepted).toList();

  Future<Contact> request(String me, ConnectionTarget target) async {
    final users = UsersRepository(db);
    UserProfile? other;
    if (target.userId != null && Validators.isUuid(target.userId)) {
      other = await users.findById(target.userId!);
    } else if (target.username != null) {
      other = await users.findByUsername(target.username!);
    } else if (target.email != null) {
      other = await users.findByEmail(Validators.normalizeEmail(target.email!));
    } else if (target.phone != null) {
      other = await users.findByPhone(target.phone!);
    }
    if (other == null) throw const ApiException.notFound('No encontramos a ese usuario.');
    if (other.id == me) {
      throw const ApiException.badRequest('No puedes agregarte a ti mismo.');
    }

    final otherId = other.id;
    final result = await db.transaction((tx) async {
      final existing = await _findPair(tx, me, otherId);
      if (existing != null) {
        final status = existing['status'] as String;
        final id = existing['id'] as String;
        final iAmRequester = existing['requester_id'] == me;
        switch (status) {
          case 'accepted':
            throw const ApiException.conflict('Ya están conectados.', code: 'already_connected');
          case 'pending' when iAmRequester:
            return (id, false);
          case 'pending':
            await _accept(tx, id);
            return (id, true);
          case 'blocked' when existing['blocked_by'] == me:
            throw const ApiException.conflict('Desbloquea a este usuario para enviarle una solicitud.');
          case 'blocked':
            // No se revela que el otro usuario te bloqueó.
            throw const ApiException.notFound('No encontramos a ese usuario.');
          case 'rejected':
            final respondedAt = existing['responded_at'] as DateTime?;
            if (iAmRequester &&
                respondedAt != null &&
                DateTime.now().toUtc().difference(respondedAt) < _rejectionCooldown) {
              throw const ApiException.conflict(
                'Ya enviaste una solicitud a este usuario. Inténtalo más adelante.',
              );
            }
            await tx.execute(
              "UPDATE connections SET requester_id = @me::uuid, addressee_id = @o::uuid, status = 'pending', "
              'responded_at = NULL, blocked_by = NULL WHERE id = @id::uuid',
              {'me': me, 'o': otherId, 'id': id},
            );
            return (id, false);
        }
      }
      final row = await tx.one(
        "INSERT INTO connections (requester_id, addressee_id, status) VALUES (@me::uuid, @o::uuid, 'pending') "
        'RETURNING id::text AS id',
        {'me': me, 'o': otherId},
      );
      final id = row!['id'] as String;
      await _ensurePermissions(tx, id, me, otherId);
      return (id, false);
    });

    final (connectionId, acceptedNow) = result;
    final meProfile = await users.findById(me);
    final name = meProfile?.displayName ?? 'Alguien';
    await notifications.notify(acceptedNow
        ? OutgoingNotification(
            userId: otherId,
            type: NotificationType.connectionAccepted,
            title: 'Nueva conexión',
            body: '$name y tú ahora están conectados.',
            data: {'connection_id': connectionId},
            dedupeKey: 'connection_accepted:$connectionId:$otherId',
          )
        : OutgoingNotification(
            userId: otherId,
            type: NotificationType.connectionRequest,
            title: 'Solicitud de conexión',
            body: '$name quiere conectarse contigo.',
            data: {'connection_id': connectionId},
            dedupeKey: 'connection_request:$connectionId:${DateTime.now().toUtc().millisecondsSinceEpoch ~/ 3600000}',
          ));
    return get(me, connectionId);
  }

  Future<Contact> accept(String me, String connectionId) async {
    final row = await db.one(
      "SELECT requester_id::text AS requester_id FROM connections "
      "WHERE id = @id::uuid AND addressee_id = @me::uuid AND status = 'pending'",
      {'id': connectionId, 'me': me},
    );
    if (row == null) throw const ApiException.notFound('La solicitud ya no está disponible.');
    await db.transaction((tx) => _accept(tx, connectionId));
    final requester = row['requester_id'] as String;
    final meProfile = await UsersRepository(db).findById(me);
    await notifications.notify(OutgoingNotification(
      userId: requester,
      type: NotificationType.connectionAccepted,
      title: 'Solicitud aceptada',
      body: '${meProfile?.displayName ?? 'Tu contacto'} aceptó tu solicitud.',
      data: {'connection_id': connectionId},
      dedupeKey: 'connection_accepted:$connectionId:$requester',
    ));
    return get(me, connectionId);
  }

  Future<void> reject(String me, String connectionId) async {
    final updated = await db.execute(
      "UPDATE connections SET status = 'rejected', responded_at = now() "
      "WHERE id = @id::uuid AND addressee_id = @me::uuid AND status = 'pending'",
      {'id': connectionId, 'me': me},
    );
    if (updated == 0) throw const ApiException.notFound('La solicitud ya no está disponible.');
  }

  Future<void> block(String me, String connectionId) => db.transaction((tx) async {
        final row = await tx.one(
          'UPDATE connections SET status = \'blocked\', blocked_by = @me::uuid, responded_at = now() '
          'WHERE id = @id::uuid AND (requester_id = @me::uuid OR addressee_id = @me::uuid) '
          "AND NOT (status = 'blocked' AND blocked_by <> @me::uuid) "
          'RETURNING (CASE WHEN requester_id = @me::uuid THEN addressee_id ELSE requester_id END)::text AS other',
          {'id': connectionId, 'me': me},
        );
        if (row == null) throw const ApiException.notFound('No encontramos ese contacto.');
        // Las alarmas pendientes o activas de la persona bloqueada dejan de llegar.
        await tx.execute(
          '''
          UPDATE alarm_recipients r SET permission_status = 'rejected'
          FROM alarms a
          WHERE r.alarm_id = a.id AND a.creator_id = @other::uuid AND r.user_id = @me::uuid
            AND r.permission_status <> 'rejected'
          ''',
          {'other': row['other'], 'me': me},
        );
      });

  Future<void> unblock(String me, String connectionId) async {
    final deleted = await db.execute(
      "DELETE FROM connections WHERE id = @id::uuid AND status = 'blocked' AND blocked_by = @me::uuid",
      {'id': connectionId, 'me': me},
    );
    if (deleted == 0) throw const ApiException.notFound('No encontramos ese contacto.');
  }

  Future<void> remove(String me, String connectionId) async {
    final deleted = await db.execute(
      'DELETE FROM connections WHERE id = @id::uuid '
      "AND (requester_id = @me::uuid OR addressee_id = @me::uuid) AND status <> 'blocked'",
      {'id': connectionId, 'me': me},
    );
    if (deleted == 0) throw const ApiException.notFound('No encontramos ese contacto.');
  }

  /// Actualiza lo que el usuario autenticado permite a este contacto.
  Future<Contact> updatePermissions(
    String me,
    String connectionId,
    ConnectionPermissions permissions,
  ) async {
    final updated = await db.execute(
      '''
      UPDATE connection_permissions p SET
        allow_alarms = @allow, auto_accept = @auto, share_response_status = @share
      FROM connections c
      WHERE p.connection_id = c.id AND c.id = @id::uuid AND p.owner_id = @me::uuid
        AND c.status IN ('pending', 'accepted')
      ''',
      {
        'id': connectionId,
        'me': me,
        'allow': permissions.allowAlarms,
        'auto': permissions.allowAlarms && permissions.autoAccept,
        'share': permissions.shareResponseStatus,
      },
    );
    if (updated == 0) throw const ApiException.notFound('No encontramos ese contacto.');
    return get(me, connectionId);
  }

  /// Permisos que [ownerId] concede a [subjectId] (solo si están conectados).
  Future<ConnectionPermissions?> permissionsGranted(Db db, String ownerId, String subjectId) async {
    final row = await db.one(
      '''
      SELECT p.allow_alarms, p.auto_accept, p.share_response_status
      FROM connection_permissions p JOIN connections c ON c.id = p.connection_id
      WHERE p.owner_id = @owner::uuid AND p.subject_id = @subject::uuid AND c.status = 'accepted'
      ''',
      {'owner': ownerId, 'subject': subjectId},
    );
    if (row == null) return null;
    return ConnectionPermissions(
      allowAlarms: row['allow_alarms'] as bool,
      autoAccept: row['auto_accept'] as bool,
      shareResponseStatus: row['share_response_status'] as bool,
    );
  }

  // ------------------------------------------------------ invitación / QR

  Future<InvitationCode> invitationCode(String me) async {
    final existing = await db.one(
      'SELECT code, expires_at FROM invitation_codes '
      "WHERE user_id = @me::uuid AND expires_at > now() + interval '1 day' AND uses < max_uses "
      'ORDER BY expires_at DESC LIMIT 1',
      {'me': me},
    );
    if (existing != null) {
      return InvitationCode(
        code: existing['code'] as String,
        expiresAt: existing['expires_at'] as DateTime,
      );
    }
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final row = await db.one(
          'INSERT INTO invitation_codes (user_id, code, expires_at) VALUES (@me::uuid, @code, @exp) '
          'RETURNING code, expires_at',
          {
            'me': me,
            'code': TokenService.randomCode(),
            'exp': DateTime.now().toUtc().add(_codeValidity),
          },
        );
        return InvitationCode(
          code: row!['code'] as String,
          expiresAt: row['expires_at'] as DateTime,
        );
      } catch (e) {
        if (!isUniqueViolation(e)) rethrow;
      }
    }
    throw StateError('No se pudo generar un código único');
  }

  /// Conecta al usuario que escanea el QR (o escribe el código) con su dueño.
  /// La conexión queda aceptada: ambos estuvieron de acuerdo en persona.
  Future<Contact> connectWithCode(String me, String rawCode) async {
    final code = InvitationCode.parsePayload(rawCode);
    if (code == null) throw const ApiException.badRequest('El código no es válido.');
    final invalidCode = const ApiException.notFound('El código no es válido o ya caducó.');

    final connectionId = await db.transaction((tx) async {
      final invite = await tx.one(
        'UPDATE invitation_codes SET uses = uses + 1 '
        'WHERE code = @code AND expires_at > now() AND uses < max_uses '
        'RETURNING user_id::text AS owner',
        {'code': code},
      );
      if (invite == null) throw invalidCode;
      final owner = invite['owner'] as String;
      if (owner == me) {
        throw const ApiException.badRequest('Este es tu propio código. Compártelo con otra persona.');
      }
      final existing = await _findPair(tx, me, owner);
      if (existing != null) {
        final id = existing['id'] as String;
        switch (existing['status']) {
          case 'accepted':
            return id;
          case 'blocked':
            throw invalidCode;
          default:
            await _accept(tx, id);
            return id;
        }
      }
      final row = await tx.one(
        "INSERT INTO connections (requester_id, addressee_id, status, responded_at) "
        "VALUES (@me::uuid, @o::uuid, 'accepted', now()) RETURNING id::text AS id",
        {'me': me, 'o': owner},
      );
      final id = row!['id'] as String;
      await _ensurePermissions(tx, id, me, owner);
      return id;
    });

    final contact = await get(me, connectionId);
    final meProfile = await UsersRepository(db).findById(me);
    await notifications.notify(OutgoingNotification(
      userId: contact.user.id,
      type: NotificationType.connectionAccepted,
      title: 'Nueva conexión',
      body: '${meProfile?.displayName ?? 'Alguien'} se conectó contigo con tu código.',
      data: {'connection_id': connectionId},
      dedupeKey: 'connection_accepted:$connectionId:${contact.user.id}',
    ));
    return contact;
  }

  // ------------------------------------------------------------ internos

  Future<Row?> _findPair(Db tx, String a, String b) => tx.one(
        '''
        SELECT id::text AS id, status, requester_id::text AS requester_id,
               blocked_by::text AS blocked_by, responded_at
        FROM connections
        WHERE LEAST(requester_id, addressee_id) = LEAST(@a::uuid, @b::uuid)
          AND GREATEST(requester_id, addressee_id) = GREATEST(@a::uuid, @b::uuid)
        FOR UPDATE
        ''',
        {'a': a, 'b': b},
      );

  Future<void> _accept(Db tx, String connectionId) async {
    await tx.execute(
      "UPDATE connections SET status = 'accepted', responded_at = now() WHERE id = @id::uuid",
      {'id': connectionId},
    );
    final row = await tx.one(
      'SELECT requester_id::text AS a, addressee_id::text AS b FROM connections WHERE id = @id::uuid',
      {'id': connectionId},
    );
    await _ensurePermissions(tx, connectionId, row!['a'] as String, row['b'] as String);
  }

  Future<void> _ensurePermissions(Db tx, String connectionId, String a, String b) async {
    for (final (owner, subject) in [(a, b), (b, a)]) {
      await tx.execute(
        'INSERT INTO connection_permissions (connection_id, owner_id, subject_id) '
        'VALUES (@c::uuid, @o::uuid, @s::uuid) ON CONFLICT (owner_id, subject_id) '
        'DO UPDATE SET connection_id = EXCLUDED.connection_id',
        {'c': connectionId, 'o': owner, 's': subject},
      );
    }
  }
}
