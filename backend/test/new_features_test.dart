@Tags(['db'])
library;

import 'package:ally_core/ally_core.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// PNG de 1x1 píxel.
const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

String _tokenFrom(String text) => RegExp(r'token=([\w-]+)').firstMatch(text)![1]!;

void main() {
  late TestApp t;

  setUpAll(() async => t = await TestApp.start());
  tearDownAll(() => t.close());

  group('Verificación y cambio de correo', () {
    test('el registro envía un enlace que verifica el correo (página web)', () async {
      final u = await t.user('Verónica');
      expect(u.profile.emailVerified, isFalse);
      final mail = t.email.sent.lastWhere((m) => m.to == u.profile.email);
      expect(mail.text, contains('https://api.example.com/verify-email?token='));

      final (status, html, _) = await t.raw('GET', '/verify-email?token=${_tokenFrom(mail.text)}');
      expect(status, 200);
      expect(html, contains('Correo confirmado'));
      final me = UserProfile.fromJson((await t.call('GET', '/api/me', token: u.token)).json);
      expect(me.emailVerified, isTrue);

      final (_, again, _) = await t.raw('GET', '/verify-email?token=${_tokenFrom(mail.text)}');
      expect(again, contains('No se pudo verificar'));
    });

    test('cambiar el correo exige contraseña y deja el nuevo sin verificar', () async {
      final u = await t.user('Walter');
      final wrong = await t.call('PUT', '/api/me/email', token: u.token, body: {
        'email': 'nuevo.walter@example.com',
        'password': 'incorrecta1',
      });
      expect(wrong.status, 422);
      final ok = await t.call('PUT', '/api/me/email', token: u.token, body: {
        'email': 'nuevo.walter@example.com',
        'password': 'secreto123',
      });
      expect(ok.status, 200);
      final me = UserProfile.fromJson(ok.json);
      expect(me.email, 'nuevo.walter@example.com');
      expect(me.emailVerified, isFalse);
      final token = _tokenFrom(t.email.sent.last.text);
      final verified = await t.call('POST', '/api/auth/email/verify', body: {'token': token});
      expect(UserProfile.fromJson(verified.json).emailVerified, isTrue);
    });

    test('reenviar verificación limita la frecuencia', () async {
      final u = await t.user('Ximena');
      final r = await t.call('POST', '/api/me/email/resend', token: u.token);
      expect(r.status, 429);
    });
  });

  group('Páginas web públicas', () {
    test('restablecer contraseña con el formulario web', () async {
      final u = await t.user('Yago');
      await t.call('POST', '/api/auth/password/forgot', body: {'email': u.profile.email});
      final link = t.email.sent.last.text;
      expect(link, contains('https://api.example.com/reset-password?token='));
      final token = _tokenFrom(link);

      final (getStatus, form, headers) = await t.raw('GET', '/reset-password?token=$token');
      expect(getStatus, 200);
      expect(form, contains('<form method="post"'));
      expect(headers['content-security-policy'], contains("default-src 'none'"));

      final (_, mismatch, _) =
          await t.raw('POST', '/reset-password', form: 'token=$token&password=nueva-clave9&confirm=otra-clave9');
      expect(mismatch, contains('no coinciden'));
      final (_, done, _) =
          await t.raw('POST', '/reset-password', form: 'token=$token&password=nueva-clave9&confirm=nueva-clave9');
      expect(done, contains('Contraseña actualizada'));
      final login = await t.call('POST', '/api/auth/login', body: {
        'identifier': u.profile.email,
        'password': 'nueva-clave9',
      });
      expect(login.status, 200);
    });

    test('página de invitación, política de privacidad y assetlinks', () async {
      final u = await t.user('Zaida');
      final code = InvitationCode.fromJson((await t.call('POST', '/api/contacts/invitation', token: u.token)).json);
      final (status, html, _) = await t.raw('GET', '/c/${code.code}');
      expect(status, 200);
      expect(html, contains('Zaida te invitó a Ally'));
      expect(html, contains('ally://connect?code=${code.code}'));
      expect((await t.raw('GET', '/c/ZZZZZZZZ')).$2, contains('Invitación no válida'));

      final (privacyStatus, privacy, _) = await t.raw('GET', '/privacy');
      expect(privacyStatus, 200);
      expect(privacy, contains('Eliminar mi cuenta'));

      final (_, links, _) = await t.raw('GET', '/.well-known/assetlinks.json');
      expect(links, contains('com.conexfor.ally'));
    });

    test('los nombres se escapan (sin inyección HTML)', () async {
      final u = await t.user('<b>x</b>');
      final code = InvitationCode.fromJson((await t.call('POST', '/api/contacts/invitation', token: u.token)).json);
      final (_, html, _) = await t.raw('GET', '/c/${code.code}');
      expect(html, isNot(contains('<b>x</b>')));
      expect(html, contains('&lt;b&gt;'));
    });
  });

  group('Foto de perfil', () {
    test('subir, ver (contactos sí, desconocidos no) y eliminar', () async {
      final a = await t.user('Andrea');
      final b = await t.user('Bastián');
      final stranger = await t.user('Extraño');
      await t.connect(a, b);

      final (status, body, _) = await t.raw('POST', '/api/me/avatar', bytes: _png, token: a.token);
      expect(status, 200, reason: body);
      final me = UserProfile.fromJson((await t.call('GET', '/api/me', token: a.token)).json);
      expect(me.avatarUrl, startsWith('/api/users/${a.id}/avatar'));

      final (contactStatus, _, headers) = await t.raw('GET', '/api/users/${a.id}/avatar', token: b.token);
      expect(contactStatus, 200);
      expect(headers['content-type'], 'image/png');
      expect(headers['cache-control'], contains('private'));
      expect((await t.raw('GET', '/api/users/${a.id}/avatar', token: stranger.token)).$1, 404);

      final (badStatus, _, _) = await t.raw('POST', '/api/me/avatar', bytes: [1, 2, 3, 4], token: a.token);
      expect(badStatus, 400);
      final (bigStatus, _, _) =
          await t.raw('POST', '/api/me/avatar', bytes: List.filled(1024 * 1024 + 10, 0), token: a.token);
      expect(bigStatus, 413);

      await t.call('DELETE', '/api/me/avatar', token: a.token);
      expect(UserProfile.fromJson((await t.call('GET', '/api/me', token: a.token)).json).avatarUrl, isNull);
    });
  });

  group('Grupos: solo administradores envían alarmas', () {
    test('con la política "admins" un miembro no puede enviar alarmas al grupo', () async {
      final owner = await t.user('Carmen');
      final member = await t.user('Darío');
      await t.connect(owner, member);
      final group = Group.fromJson((await t.call('POST', '/api/groups', token: owner.token, body: {
        'name': 'Oficina',
        'member_ids': [member.id],
      }))
          .json);
      await t.call('POST', '/api/groups/${group.id}/accept', token: member.token);
      final updated = Group.fromJson((await t.call('PUT', '/api/groups/${group.id}', token: owner.token, body: {
        'name': 'Oficina',
        'alarm_policy': 'admins',
      }))
          .json);
      expect(updated.alarmPolicy, GroupAlarmPolicy.admins);

      final denied = await t.call('POST', '/api/alarms', token: member.token, body: {
        'title': 'Reunión',
        ...tomorrowAt(9),
        'recipients': [{'type': 'group', 'id': group.id}],
      });
      expect(denied.status, 403);
      final allowed = await t.call('POST', '/api/alarms', token: owner.token, body: {
        'title': 'Reunión',
        ...tomorrowAt(9),
        'recipients': [{'type': 'group', 'id': group.id}],
      });
      expect(allowed.status, 201);
    });
  });

  group('Rutinas (alarmas encadenadas)', () {
    Map<String, Object?> routine(List<(String, String)> steps, {List<Map<String, String>> recipients = const []}) {
      final date = tomorrowAt(7);
      return {
        'name': 'Mañana',
        'local_date': date['local_date'],
        'timezone': 'America/Bogota',
        'recipients': recipients,
        'steps': [for (final (time, title) in steps) {'title': title, 'local_time': time}],
      };
    }

    test('crear, listar, ver en las alarmas y eliminar', () async {
      final a = await t.user('Elisa');
      final b = await t.user('Fermín');
      await t.connect(a, b, autoAccept: true);
      final r = await t.call('POST', '/api/sequences', token: a.token, body: routine(
        [('07:00', 'Despertar'), ('07:15', 'Prepararse'), ('07:30', 'Salir de casa'), ('08:00', 'Llegar')],
        recipients: [{'type': 'user', 'id': b.id}],
      ));
      expect(r.status, 201, reason: '${r.body}');
      final sequence = AlarmSequence.fromJson(r.json);
      expect(sequence.steps.map((s) => s.offsetMinutes), [0, 15, 30, 60]);

      final alarms = (await t.call('GET', '/api/alarms', token: b.token)).json['alarms'] as List;
      final received = [for (final a in alarms) Alarm.fromJson(a as Map<String, dynamic>)];
      expect(received.where((x) => x.sequenceId == sequence.id), hasLength(4));
      expect(received.firstWhere((x) => x.title == 'Prepararse').sequencePosition, 1);

      final inbox = (await t.call('GET', '/api/notifications', token: b.token)).json['notifications'] as List;
      expect(inbox.where((n) => (n as Map)['title'] == 'Nueva rutina de Elisa'), hasLength(1));

      expect((await t.call('DELETE', '/api/sequences/${sequence.id}', token: a.token)).status, 204);
      final after = (await t.call('GET', '/api/alarms', token: b.token)).json['alarms'] as List;
      expect(after.where((x) => (x as Map)['sequence_id'] == sequence.id), isEmpty);
      expect((await t.call('GET', '/api/sequences', token: a.token)).json['sequences'], isEmpty);
    });

    test('pasos desordenados o insuficientes se rechazan', () async {
      final a = await t.user('Gloria');
      final unordered = await t.call('POST', '/api/sequences', token: a.token, body: routine([('07:30', 'B'), ('07:00', 'A')]));
      expect(unordered.status, 422);
      final single = await t.call('POST', '/api/sequences', token: a.token, body: routine([('07:00', 'Solo')]));
      expect(single.status, 422);
    });

    test('si un paso falla no queda nada creado', () async {
      final a = await t.user('Hernán');
      final stranger = await t.user('Inés Extraña');
      final r = await t.call('POST', '/api/sequences', token: a.token, body: routine(
        [('07:00', 'A'), ('07:30', 'B')],
        recipients: [{'type': 'user', 'id': stranger.id}],
      ));
      expect(r.status, 403);
      expect((await t.call('GET', '/api/alarms', token: a.token)).json['alarms'], isEmpty);
    });
  });
}
