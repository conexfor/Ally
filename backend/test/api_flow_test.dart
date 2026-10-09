@Tags(['db'])
library;

import 'package:ally_core/ally_core.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late TestApp t;

  setUpAll(() async => t = await TestApp.start());
  tearDownAll(() => t.close());

  group('Flujo completo (resultado final esperado)', () {
    test('Nicolás crea una alarma para Juan, Juan confirma y Nicolás ve el estado', () async {
      // 1-2. Registro y perfil.
      final nicolas = await t.user('Nicolás');
      final juan = await t.user('Juan');

      // 3-5. Conexión y "permitir automáticamente".
      await t.connect(nicolas, juan, autoAccept: true);

      // 6-9. El asistente interpreta la frase (sin IA).
      final parse = await t.call('POST', '/api/parser/parse', token: nicolas.token, body: {
        'text': 'Crea una alarma mañana a las 8 para Juan que diga reunión de proyecto',
      });
      expect(parse.status, 200);
      final interpretation = InterpretationResult.fromJson(parse.json);
      expect(interpretation.status, InterpretationStatus.needsConfirmation);
      final draft = interpretation.draft;
      expect(draft.time, LocalTime(8, 0));
      expect(draft.message, 'Reunión de proyecto');
      expect(draft.recipients.single.id, juan.id);
      expect(interpretation.confirmation!.toPlainText(), contains('⏰ 08:00 AM'));

      // 10-11. Confirma y el backend crea la alarma.
      final create = await t.call('POST', '/api/alarms', token: nicolas.token, body: {
        'title': draft.message,
        'message': draft.message,
        'local_date': draft.date.toString(),
        'local_time': draft.time.toString(),
        'timezone': 'America/Bogota',
        'recipients': [
          {'type': 'user', 'id': juan.id},
        ],
      });
      expect(create.status, 201, reason: '${create.body}');
      final alarm = Alarm.fromJson(create.json);
      expect(alarm.recipients.single.permissionStatus, PermissionStatus.accepted);

      // 12. Juan la recibe (notificación + sincronización).
      final inbox = await t.call('GET', '/api/notifications', token: juan.token);
      final notifications = (inbox.json['notifications'] as List).cast<Map<String, dynamic>>();
      expect(notifications.first['type'], 'alarm_new');
      final sync = SyncPayload.fromJson((await t.call('GET', '/api/sync?cursor=0', token: juan.token)).json);
      expect(sync.alarms.map((a) => a.id), contains(alarm.id));

      // 13-14. Suena en el teléfono de Juan y confirma.
      final confirm = await t.call('POST', '/api/alarms/${alarm.id}/confirm', token: juan.token, body: {
        'occurrence_at': alarm.nextOccurrenceAt!.toIso8601String(),
      });
      expect(confirm.status, 200, reason: '${confirm.body}');

      // 15. Nicolás ve "Juan 🟢 Confirmó".
      final seen = Alarm.fromJson((await t.call('GET', '/api/alarms/${alarm.id}', token: nicolas.token)).json);
      expect(seen.recipientFor(juan.id)!.responseStatus, ResponseStatus.confirmed);
      final creatorInbox = await t.call('GET', '/api/notifications', token: nicolas.token);
      expect(
        (creatorInbox.json['notifications'] as List).cast<Map<String, dynamic>>().map((n) => n['type']),
        contains('alarm_confirmed'),
      );
    });
  });

  group('Permisos de conexión', () {
    test('sin auto-aceptar la alarma queda pendiente y se puede aceptar', () async {
      final a = await t.user('Ana');
      final b = await t.user('Beto');
      await t.connect(a, b);
      final r = await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Llamar',
        ...tomorrowAt(9),
        'recipients': [{'type': 'user', 'id': b.id}],
      });
      final alarm = Alarm.fromJson(r.json);
      expect(alarm.recipients.single.permissionStatus, PermissionStatus.pending);
      final accepted = await t.call('POST', '/api/alarms/${alarm.id}/accept', token: b.token);
      expect(Alarm.fromJson(accepted.json).recipientFor(b.id)!.permissionStatus, PermissionStatus.accepted);
    });

    test('no se pueden enviar alarmas a quien no es contacto', () async {
      final a = await t.user('Carla');
      final stranger = await t.user('Desconocido');
      final r = await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Hola',
        ...tomorrowAt(9),
        'recipients': [{'type': 'user', 'id': stranger.id}],
      });
      expect(r.status, 403);
    });

    test('quien desactiva "permitir alarmas" no las recibe', () async {
      final a = await t.user('Diego');
      final b = await t.user('Elena');
      final connection = await t.connect(a, b);
      await t.call('PUT', '/api/contacts/$connection/permissions', token: b.token, body: {
        'allow_alarms': false,
        'auto_accept': false,
        'share_response_status': true,
      });
      final r = await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Hola',
        ...tomorrowAt(9),
        'recipients': [{'type': 'user', 'id': b.id}],
      });
      expect(r.status, 403);
      expect((r.json['error'] as Map)['message'], 'Elena no acepta alarmas tuyas.');
    });

    test('si el destinatario no comparte respuestas, el creador no las ve', () async {
      final a = await t.user('Fede');
      final b = await t.user('Gabi');
      final connection = await t.connect(a, b, autoAccept: true);
      await t.call('PUT', '/api/contacts/$connection/permissions', token: b.token, body: {
        'allow_alarms': true,
        'auto_accept': true,
        'share_response_status': false,
      });
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Privada',
        ...tomorrowAt(10),
        'recipients': [{'type': 'user', 'id': b.id}],
      }))
          .json);
      await t.call('POST', '/api/alarms/${alarm.id}/snooze', token: b.token, body: {
        'occurrence_at': alarm.nextOccurrenceAt!.toIso8601String(),
        'snooze_minutes': 10,
      });
      final seen = Alarm.fromJson((await t.call('GET', '/api/alarms/${alarm.id}', token: a.token)).json);
      expect(seen.recipientFor(b.id)!.responseStatus, ResponseStatus.noResponse);
      final own = Alarm.fromJson((await t.call('GET', '/api/alarms/${alarm.id}', token: b.token)).json);
      expect(own.recipientFor(b.id)!.responseStatus, ResponseStatus.snoozed);
    });
  });

  group('Seguridad: aislamiento de datos', () {
    test('cambiar el ID no da acceso a alarmas ajenas', () async {
      final owner = await t.user('Hugo');
      final intruder = await t.user('Intruso');
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: owner.token, body: {
        'title': 'Secreta',
        ...tomorrowAt(7),
      }))
          .json);
      for (final (method, path) in [
        ('GET', '/api/alarms/${alarm.id}'),
        ('PUT', '/api/alarms/${alarm.id}'),
        ('DELETE', '/api/alarms/${alarm.id}'),
        ('POST', '/api/alarms/${alarm.id}/cancel'),
        ('GET', '/api/alarms/${alarm.id}/responses'),
      ]) {
        final r = await t.call(method, path, token: intruder.token, body: {
          'title': 'Hackeada',
          ...tomorrowAt(7),
        });
        expect(r.status, 404, reason: '$method $path');
      }
      final still = Alarm.fromJson((await t.call('GET', '/api/alarms/${alarm.id}', token: owner.token)).json);
      expect(still.title, 'Secreta');
    });

    test('un destinatario no puede editar la alarma', () async {
      final a = await t.user('Iván');
      final b = await t.user('Julia');
      await t.connect(a, b, autoAccept: true);
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Compartida',
        ...tomorrowAt(7),
        'recipients': [{'type': 'user', 'id': b.id}],
      }))
          .json);
      final r = await t.call('PUT', '/api/alarms/${alarm.id}', token: b.token, body: {
        'title': 'Cambiada',
        ...tomorrowAt(7),
      });
      expect(r.status, 403);
    });

    test('sin token o con token falso: 401', () async {
      expect((await t.call('GET', '/api/alarms')).status, 401);
      expect((await t.call('GET', '/api/alarms', token: 'abc.def.ghi')).status, 401);
    });

    test('IDs mal formados no provocan errores internos', () async {
      final u = await t.user('Karen');
      final r = await t.call('GET', "/api/alarms/1' OR '1'='1", token: u.token);
      expect(r.status, 404);
    });

    test('los errores nunca exponen detalles técnicos', () async {
      final u = await t.user('Luis');
      final r = await t.call('POST', '/api/alarms', token: u.token, body: {'title': 5});
      expect(r.status, 400);
      expect((r.json['error'] as Map)['message'], isNot(contains('Exception')));
    });
  });

  group('Alarmas', () {
    test('creación idempotente con ID del cliente (cola offline)', () async {
      final u = await t.user('Mario');
      const id = '7d3c2a8e-6d3c-4e2f-9a55-3a4f7c2e1d42';
      final body = {'id': id, 'title': 'Offline', ...tomorrowAt(6, minute: 30)};
      final first = await t.call('POST', '/api/alarms', token: u.token, body: body);
      final second = await t.call('POST', '/api/alarms', token: u.token, body: body);
      expect(first.status, 201);
      expect(second.status, 201);
      expect(second.json['id'], id);
      final list = await t.call('GET', '/api/alarms', token: u.token);
      expect((list.json['alarms'] as List).where((a) => (a as Map)['id'] == id), hasLength(1));
    });

    test('conflicto de versión al editar desde dos dispositivos', () async {
      final u = await t.user('Nora');
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: u.token, body: {
        'title': 'V1',
        ...tomorrowAt(6),
      }))
          .json);
      final ok = await t.call('PUT', '/api/alarms/${alarm.id}', token: u.token, body: {
        'title': 'V2',
        ...tomorrowAt(6),
        'base_version': 1,
      });
      expect(ok.status, 200);
      final stale = await t.call('PUT', '/api/alarms/${alarm.id}', token: u.token, body: {
        'title': 'V2 desde otro dispositivo',
        ...tomorrowAt(6),
        'base_version': 1,
      });
      expect(stale.status, 409);
      expect(stale.errorCode, 'version_conflict');
    });

    test('alarma en el pasado se rechaza', () async {
      final u = await t.user('Olga');
      final r = await t.call('POST', '/api/alarms', token: u.token, body: {
        'title': 'Ayer',
        'local_date': '2020-01-01',
        'local_time': '08:00',
        'timezone': 'America/Bogota',
      });
      expect(r.status, 422);
    });

    test('recurrente: cancelar la próxima ocurrencia avanza a la siguiente', () async {
      final u = await t.user('Pablo');
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: u.token, body: {
        'title': 'Diaria',
        ...tomorrowAt(7),
        'repeat_rule': RepeatRule.daily().toJson(),
      }))
          .json);
      final cancelled = Alarm.fromJson(
        (await t.call('POST', '/api/alarms/${alarm.id}/cancel', token: u.token)).json,
      );
      expect(cancelled.nextOccurrenceAt, alarm.nextOccurrenceAt!.add(const Duration(days: 1)));
      final history = await t.call('GET', '/api/history?filter=cancelled', token: u.token);
      expect(history.status, 200);
    });

    test('posponer y respuesta en ocurrencia inexistente', () async {
      final u = await t.user('Quique');
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: u.token, body: {
        'title': 'Personal',
        ...tomorrowAt(8),
      }))
          .json);
      final wrong = await t.call('POST', '/api/alarms/${alarm.id}/snooze', token: u.token, body: {
        'occurrence_at': alarm.nextOccurrenceAt!.add(const Duration(minutes: 3)).toIso8601String(),
      });
      expect(wrong.status, 400);
      final ok = await t.call('POST', '/api/alarms/${alarm.id}/snooze', token: u.token, body: {
        'occurrence_at': alarm.nextOccurrenceAt!.toIso8601String(),
        'snooze_minutes': 5,
      });
      expect(ok.status, 200);
      final responses = await t.call('GET', '/api/alarms/${alarm.id}/responses', token: u.token);
      final response = AlarmResponse.fromJson((responses.json['responses'] as List).single as Map<String, dynamic>);
      expect(response.response, ResponseStatus.snoozed);
      expect(response.snoozedUntil, isNotNull);
    });

    test('eliminar notifica a los destinatarios una sola vez', () async {
      final a = await t.user('Rosa');
      final b = await t.user('Samuel');
      await t.connect(a, b, autoAccept: true);
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Se cancela',
        ...tomorrowAt(9),
        'recipients': [{'type': 'user', 'id': b.id}],
      }))
          .json);
      await t.call('DELETE', '/api/alarms/${alarm.id}', token: a.token);
      await t.call('DELETE', '/api/alarms/${alarm.id}', token: a.token);
      final inbox = await t.call('GET', '/api/notifications', token: b.token);
      final cancelled = (inbox.json['notifications'] as List)
          .cast<Map<String, dynamic>>()
          .where((n) => n['type'] == 'alarm_cancelled');
      expect(cancelled, hasLength(1));
      // La sincronización entrega la lápida.
      final sync = SyncPayload.fromJson((await t.call('GET', '/api/sync?cursor=0', token: b.token)).json);
      expect(sync.alarms.singleWhere((x) => x.id == alarm.id).isDeleted, isTrue);
    });
  });

  group('Grupos', () {
    test('alarma para un grupo llega a sus miembros activos', () async {
      final owner = await t.user('Tomás');
      final m1 = await t.user('Úrsula');
      final m2 = await t.user('Víctor');
      await t.connect(owner, m1);
      await t.connect(owner, m2);
      final group = Group.fromJson((await t.call('POST', '/api/groups', token: owner.token, body: {
        'name': 'Equipo Desarrollo',
        'member_ids': [m1.id, m2.id],
      }))
          .json);
      expect(group.members.where((m) => m.status == MemberStatus.invited), hasLength(2));
      await t.call('POST', '/api/groups/${group.id}/accept', token: m1.token);

      final parse = await t.call('POST', '/api/parser/parse', token: owner.token, body: {
        'text': 'Todos los lunes a las 9 para el equipo',
      });
      final draft = InterpretationResult.fromJson(parse.json).draft;
      expect(draft.recipients.single.id, group.id);

      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: owner.token, body: {
        'title': 'Daily',
        'local_date': draft.date.toString(),
        'local_time': draft.time.toString(),
        'timezone': 'America/Bogota',
        'repeat_rule': draft.repeat!.toJson(),
        'recipients': [{'type': 'group', 'id': group.id}],
      }))
          .json);
      final userRows = alarm.recipients.where((r) => r.recipientType == RecipientType.user);
      expect(userRows.map((r) => r.userId), containsAll([owner.id, m1.id]));
      expect(userRows.map((r) => r.userId), isNot(contains(m2.id)));

      final stats = await t.call('GET', '/api/stats', token: owner.token);
      final groupStats = (stats.json['groups'] as List).cast<Map<String, dynamic>>();
      expect(groupStats.single['alarms_this_month'], 1);
    });

    test('no se puede agregar a quien no es contacto', () async {
      final owner = await t.user('Wendy');
      final stranger = await t.user('Xavi');
      final r = await t.call('POST', '/api/groups', token: owner.token, body: {
        'name': 'Familia',
        'member_ids': [stranger.id],
      });
      expect(r.status, 400);
    });

    test('quien no pertenece al grupo no lo ve', () async {
      final owner = await t.user('Yolanda');
      final other = await t.user('Zoe');
      final group = Group.fromJson((await t.call('POST', '/api/groups', token: owner.token, body: {
        'name': 'Universidad',
      }))
          .json);
      expect((await t.call('GET', '/api/groups/${group.id}', token: other.token)).status, 404);
    });
  });

  group('Contactos', () {
    test('código QR crea una conexión aceptada', () async {
      final a = await t.user('Alba');
      final b = await t.user('Bruno');
      final invitation = InvitationCode.fromJson(
        (await t.call('POST', '/api/contacts/invitation', token: a.token)).json,
      );
      final r = await t.call('POST', '/api/contacts/connect', token: b.token, body: {
        'code': invitation.qrPayload,
      });
      expect(r.status, 200);
      expect(Contact.fromJson(r.json).status, ConnectionStatus.accepted);
      final own = await t.call('POST', '/api/contacts/connect', token: a.token, body: {
        'code': invitation.code,
      });
      expect(own.status, 400);
    });

    test('bloquear oculta al usuario y rechaza sus alarmas', () async {
      final a = await t.user('Ceci');
      final b = await t.user('Dani');
      final connection = await t.connect(a, b, autoAccept: true);
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Molesta',
        ...tomorrowAt(9),
        'recipients': [{'type': 'user', 'id': b.id}],
      }))
          .json);
      await t.call('POST', '/api/contacts/$connection/block', token: b.token);
      expect((await t.call('GET', '/api/alarms/${alarm.id}', token: b.token)).status, 404);
      final contactsOfA = await t.call('GET', '/api/contacts', token: a.token);
      expect(contactsOfA.json['contacts'], isEmpty);
      final retry = await t.call('POST', '/api/contacts/request', token: a.token, body: {'user_id': b.id});
      expect(retry.status, 404);
    });

    test('búsqueda por @usuario', () async {
      final a = await t.user('Eva');
      final b = await t.user('Fabián');
      final r = await t.call('GET', '/api/users/search?q=@${b.profile.username}', token: a.token);
      expect((r.json['users'] as List).single['id'], b.id);
    });
  });

  group('Autenticación', () {
    test('rotación de refresh token y detección de reutilización', () async {
      final u = await t.user('Gema');
      final first = await t.call('POST', '/api/auth/refresh', body: {'refresh_token': u.refreshToken});
      expect(first.status, 200);
      final rotated = AuthSession.fromJson(first.json);
      // Reutilizar el token viejo revoca todas las sesiones.
      final reuse = await t.call('POST', '/api/auth/refresh', body: {'refresh_token': u.refreshToken});
      expect(reuse.status, 401);
      final afterReuse = await t.call('POST', '/api/auth/refresh', body: {'refresh_token': rotated.refreshToken});
      expect(afterReuse.status, 401);
    });

    test('login con usuario o correo; contraseña incorrecta', () async {
      final u = await t.user('Héctor');
      final ok = await t.call('POST', '/api/auth/login', body: {
        'identifier': '@${u.profile.username}',
        'password': 'secreto123',
      });
      expect(ok.status, 200);
      final bad = await t.call('POST', '/api/auth/login', body: {
        'identifier': u.profile.email,
        'password': 'otra-cosa1',
      });
      expect(bad.status, 401);
    });

    test('recuperación de contraseña', () async {
      final u = await t.user('Inés');
      final r = await t.call('POST', '/api/auth/password/forgot', body: {'email': u.profile.email});
      expect(r.status, 200);
      final mail = t.email.sent.last;
      final token = RegExp(r'token=([\w-]+)').firstMatch(mail.text)![1]!;
      final reset = await t.call('POST', '/api/auth/password/reset', body: {
        'token': token,
        'password': 'nueva-clave9',
      });
      expect(reset.status, 200);
      final again = await t.call('POST', '/api/auth/password/reset', body: {
        'token': token,
        'password': 'otra-clave9',
      });
      expect(again.status, 400);
      final login = await t.call('POST', '/api/auth/login', body: {
        'identifier': u.profile.email,
        'password': 'nueva-clave9',
      });
      expect(login.status, 200);
    });

    test('validación del registro', () async {
      final r = await t.call('POST', '/api/auth/register', body: {
        'email': 'no-es-correo',
        'password': 'corta',
        'username': 'A',
        'display_name': '',
      });
      expect(r.status, 422);
      expect((r.json['error'] as Map)['fields'], containsPair('email', 'El correo no es válido.'));
    });
  });

  group('Mantenimiento e historial', () {
    test('las ocurrencias vencidas pasan al historial', () async {
      final u = await t.user('Jorge');
      final alarm = Alarm.fromJson((await t.call('POST', '/api/alarms', token: u.token, body: {
        'title': 'Para historial',
        ...tomorrowAt(5, minute: 15),
      }))
          .json);
      final processed = await t.app.maintenance.runOnce(
        now: alarm.nextOccurrenceAt!.add(const Duration(minutes: 1)),
      );
      expect(processed, greaterThanOrEqualTo(1));
      final updated = Alarm.fromJson((await t.call('GET', '/api/alarms/${alarm.id}', token: u.token)).json);
      expect(updated.status, AlarmStatus.completed);
      expect(updated.nextOccurrenceAt, isNull);
    });
  });

  group('Dispositivos y push', () {
    test('registrar dispositivo y recibir push de datos al crear alarma', () async {
      final a = await t.user('Karla');
      final b = await t.user('Leo');
      await t.connect(a, b, autoAccept: true);
      final device = await t.call('POST', '/api/devices', token: b.token, body: {
        'device_name': 'Teléfono de Leo',
        'device_type': 'phone',
        'platform': 'android',
        'push_token': 'token-leo',
        'timezone': 'America/Bogota',
      });
      expect(device.status, 201);
      t.push.sent.clear();
      await t.call('POST', '/api/alarms', token: a.token, body: {
        'title': 'Push',
        ...tomorrowAt(9),
        'recipients': [{'type': 'user', 'id': b.id}],
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final toLeo = t.push.sent.where((m) => m.token == 'token-leo');
      expect(toLeo, isNotEmpty);
      expect(toLeo.first.dataOnly, isTrue);
      expect(toLeo.first.data['type'], 'alarm_new');
    });
  });
}
