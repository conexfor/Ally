import 'dart:convert';
import 'dart:io';

import 'package:backend/src/app.dart';
import 'package:backend/src/config/app_config.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/db/migrator.dart';
import 'package:backend/src/modules/notifications/email_sender.dart';
import 'package:backend/src/modules/notifications/push_sender.dart';
import 'package:backend/src/security/password_hasher.dart';
import 'package:shelf/shelf.dart';
import 'package:ally_core/ally_core.dart';

/// URL de la base de datos de pruebas (se borra y recrea en cada ejecución).
String get testDatabaseUrl =>
    Platform.environment['TEST_DATABASE_URL'] ??
    'postgresql://ally:devpass@localhost:54329/ally_test?sslmode=disable';

class RecordingPush implements PushSender {
  final sent = <PushMessage>[];
  @override
  Future<Set<String>> send(List<PushMessage> messages) async {
    sent.addAll(messages);
    return const {};
  }
}

class RecordingEmail implements EmailSender {
  final sent = <({String to, String subject, String text})>[];
  @override
  Future<void> send({required String to, required String subject, required String text}) async {
    sent.add((to: to, subject: subject, text: text));
  }
}

class TestApp {
  final Application app;
  final Database db;
  final RecordingPush push;
  final RecordingEmail email;
  var _counter = 0;

  TestApp._(this.app, this.db, this.push, this.email);

  static Future<TestApp> start() async {
    final db = Database.connect(testDatabaseUrl, maxConnections: 4);
    await db.execute('DROP SCHEMA public CASCADE');
    await db.execute('CREATE SCHEMA public');
    await db.execute('DROP SEQUENCE IF EXISTS global_sync_seq');
    await Migrator(db, Directory('migrations')).migrate();
    final config = AppConfig.fromEnvironment({
      'DATABASE_URL': testDatabaseUrl,
      'JWT_SECRET': 'test-secret-test-secret-test-secret-123',
      'RATE_LIMIT_PER_MINUTE': '100000',
      'AUTH_RATE_LIMIT_PER_MINUTE': '100000',
      'PUBLIC_BASE_URL': 'https://api.example.com',
      'ANDROID_PACKAGE_NAME': 'com.conexfor.ally',
      'ANDROID_SHA256_CERT_FINGERPRINTS': 'AA:BB',
    });
    final push = RecordingPush();
    final email = RecordingEmail();
    final app = Application.build(
      config,
      db,
      push: push,
      email: email,
      hasher: const PasswordHasher(cost: 4),
    );
    return TestApp._(app, db, push, email);
  }

  Future<void> close() => db.close();

  Future<TestResponse> call(
    String method,
    String path, {
    Object? body,
    String? token,
    String? deviceId,
  }) async {
    final response = await app.handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
        'x-device-id': ?deviceId,
      },
    ));
    final text = await response.readAsString();
    return TestResponse(response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  /// Registra un usuario nuevo con nombre único.
  Future<TestUser> user(String displayName, {String timezone = 'America/Bogota'}) async {
    final n = ++_counter;
    final username = '${TextNormalizer.nameKey(displayName).replaceAll(' ', '')}$n';
    final r = await call('POST', '/api/auth/register', body: {
      'email': '$username@example.com',
      'password': 'secreto123',
      'username': username,
      'display_name': displayName,
      'timezone': timezone,
    });
    if (r.status != 201) throw StateError('No se pudo registrar: ${r.body}');
    final session = AuthSession.fromJson(r.json);
    return TestUser(session.user, session.accessToken, session.refreshToken);
  }

  /// Conecta a dos usuarios; [autoAccept]: b acepta automáticamente alarmas de a.
  Future<String> connect(TestUser a, TestUser b, {bool autoAccept = false}) async {
    final r = await call('POST', '/api/contacts/request', token: a.token, body: {'user_id': b.id});
    final id = r.json['connection_id'] as String;
    await call('POST', '/api/contacts/$id/accept', token: b.token);
    if (autoAccept) {
      await call('PUT', '/api/contacts/$id/permissions', token: b.token, body: {
        'allow_alarms': true,
        'auto_accept': true,
        'share_response_status': true,
      });
    }
    return id;
  }
}

class TestUser {
  final UserProfile profile;
  final String token;
  final String refreshToken;
  TestUser(this.profile, this.token, this.refreshToken);
  String get id => profile.id;
}

class TestResponse {
  final int status;
  final dynamic body;
  TestResponse(this.status, this.body);

  Map<String, dynamic> get json => body as Map<String, dynamic>;
  String? get errorCode => (json['error'] as Map?)?['code'] as String?;

  @override
  String toString() => 'TestResponse($status, $body)';
}

extension RawCalls on TestApp {
  /// Petición con cuerpo binario o de formulario y respuesta en texto.
  Future<(int, String, Map<String, String>)> raw(
    String method,
    String path, {
    List<int>? bytes,
    String? form,
    String? token,
  }) async {
    final response = await app.handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: bytes ?? form,
      headers: {
        if (form != null) 'content-type': 'application/x-www-form-urlencoded',
        if (bytes != null) 'content-type': 'application/octet-stream',
        if (token != null) 'authorization': 'Bearer $token',
      },
    ));
    return (response.statusCode, await response.readAsString(), response.headers);
  }
}

/// Fecha/hora local de mañana a las [hour] en Bogotá, en formato de API.
Map<String, String> tomorrowAt(int hour, {int minute = 0}) {
  final local = ZonedSchedule.toLocal(DateTime.now().toUtc(), 'America/Bogota').date.addDays(1);
  return {
    'local_date': local.toString(),
    'local_time': LocalTime(hour, minute).toString(),
    'timezone': 'America/Bogota',
  };
}
