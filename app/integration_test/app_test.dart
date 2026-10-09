// Se ejecuta en un dispositivo/emulador Android:
//   flutter test integration_test -d <dispositivo> --dart-define=API_BASE_URL=http://10.0.2.2:8080
//
// Incluye los tests de la app y un flujo completo real contra el backend
// (registro, conexión, asistente, sincronización, alarma nativa programada,
// confirmación y estado visible para el creador).
import 'package:alarm/alarm.dart' as native;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ally/application/assistant/command_executor.dart';
import 'package:ally/application/assistant/context_builder.dart';
import 'package:ally/core/config/env.dart';
import 'package:ally/data/local/app_database.dart';
import 'package:ally/data/local/local_store.dart';
import 'package:ally/data/remote/api_client.dart';
import 'package:ally/data/remote/ally_api.dart';
import 'package:ally/data/remote/token_store.dart';
import 'package:ally/data/repositories/alarm_repository.dart';
import 'package:ally/data/repositories/auth_repository.dart';
import 'package:ally/data/repositories/social_repository.dart';
import 'package:ally/services/alarm_scheduler.dart';
import 'package:ally/services/device_service.dart';
import 'package:ally/services/sync_engine.dart';
import 'package:ally_core/ally_core.dart';

import '../test/command_executor_test.dart' as executor_test;
import '../test/sync_engine_test.dart' as sync_engine_test;
import '../test/widgets_test.dart' as widgets_test;

/// Tokens en memoria para tener dos usuarios independientes en la prueba.
class MemoryTokenStore extends TokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<void> load() async {}
  @override
  String? get accessToken => _access;
  @override
  String? get refreshToken => _refresh;
  @override
  bool get hasSession => _refresh != null;
  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clear() async => _access = _refresh = null;
}

/// Un "teléfono" completo: base de datos, API, sincronización y alarmas.
class TestClient {
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  late final LocalStore store = LocalStore(db);
  final MemoryTokenStore tokens = MemoryTokenStore();
  late final ApiClient client = ApiClient(baseUrl: Env.apiBaseUrl, tokens: tokens);
  late final AllyApi api = AllyApi(client);
  late final AlarmScheduler scheduler = AlarmScheduler(store);
  late final SyncEngine sync = SyncEngine(api, store, scheduler);
  late final AuthRepository auth = AuthRepository(api, tokens, store, scheduler);
  late final AlarmRepository alarms = AlarmRepository(api, store, scheduler);
  late final SocialRepository social = SocialRepository(api, store);
  late final DeviceService devices = DeviceService(api, client, store);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Dos "teléfonos" simulados = dos bases de datos en memoria (intencionado).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Sincronización offline', sync_engine_test.main);
  group('Ejecución de comandos', executor_test.main);
  group('Componentes de la interfaz', widgets_test.main);

  testWidgets('Flujo completo: Nicolás crea una alarma para Juan con el asistente', (tester) async {
    await native.Alarm.init();
    ZonedSchedule.ensureInitialized();
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final nicolas = TestClient();
    final juan = TestClient();

    // 1-2. Registro.
    await nicolas.auth.register(
      email: 'nicolas.$suffix@example.com',
      password: 'secreto123',
      username: 'nicolas_$suffix',
      displayName: 'Nicolás',
    );
    final juanProfile = await juan.auth.register(
      email: 'juan.$suffix@example.com',
      password: 'secreto123',
      username: 'juan_$suffix',
      displayName: 'Juan Pérez',
    );
    await juan.devices.register();

    // 3-5. Conexión y "permitir automáticamente".
    final request = await nicolas.social.request(username: juanProfile.username);
    final accepted = await juan.social.accept(request.connectionId);
    await juan.social.updatePermissions(
      accepted.connectionId,
      const ConnectionPermissions(allowAlarms: true, autoAccept: true, shareResponseStatus: true),
    );
    await nicolas.sync.sync();

    // 6-9. El asistente interpreta la frase en el dispositivo (sin IA).
    final timezone = await DeviceService.currentTimezone();
    final ctx = await InterpretationContextBuilder(nicolas.store).build(timezone: timezone);
    final result = RuleBasedCommandInterpreter()
        .interpretSync('Crea una alarma mañana a las 8 para Juan que diga reunión de proyecto', ctx);
    expect(result.status, InterpretationStatus.needsConfirmation);
    expect(result.confirmation!.toPlainText(), contains('⏰ 08:00 AM'));
    expect(result.draft.recipients.single.id, juanProfile.id);

    // 10-11. Confirmar → el backend crea la alarma.
    final execution = await CommandExecutor(nicolas.alarms, nicolas.social, nicolas.store).execute(result.draft);
    expect(execution.reply, startsWith('Alarma creada'));

    // 12-13. Juan sincroniza y su teléfono programa la alarma nativa.
    final sync = await juan.sync.sync();
    expect(sync.success, isTrue);
    final received = (await juan.store.alarms()).single;
    expect(received.title, 'Reunión de proyecto');
    final scheduled = await juan.store.scheduledNative();
    expect(scheduled.where((s) => s.alarmId == received.id), hasLength(1));
    final nativeAlarms = await native.Alarm.getAlarms();
    expect(nativeAlarms.map((a) => a.id), contains(scheduled.first.nativeId));

    // 14. Juan confirma: deja de estar programada en su teléfono.
    await juan.alarms.respond(received, received.nextOccurrenceAt!, ResponseStatus.confirmed);
    expect((await juan.store.scheduledNative()).where((s) => s.alarmId == received.id), isEmpty);

    // 15. Nicolás ve "Juan 🟢 Confirmó" y recibió la notificación.
    await nicolas.sync.sync();
    final seen = (await nicolas.store.alarm(received.id))!;
    expect(seen.recipientFor(juanProfile.id)!.responseStatus, ResponseStatus.confirmed);

    await juan.scheduler.stopAll();
    await nicolas.db.close();
    await juan.db.close();
  });
}
