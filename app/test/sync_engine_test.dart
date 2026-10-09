import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ally/core/errors/app_exception.dart';
import 'package:ally/data/local/app_database.dart';
import 'package:ally/data/local/local_store.dart';
import 'package:ally/data/remote/api_client.dart';
import 'package:ally/data/remote/ally_api.dart';
import 'package:ally/data/remote/token_store.dart';
import 'package:ally/data/repositories/alarm_repository.dart';
import 'package:ally/services/alarm_scheduler.dart';
import 'package:ally/services/sync_engine.dart';
import 'package:ally_core/ally_core.dart';

/// API falsa: simula el servidor y la falta de conexión.
class FakeApi extends AllyApi {
  bool online = true;
  final server = <String, Alarm>{};
  int createCalls = 0;
  bool conflictOnUpdate = false;

  FakeApi() : super(ApiClient(baseUrl: 'http://test', tokens: TokenStore()));

  void _check() {
    if (!online) throw const AppException.network();
  }

  @override
  Future<Alarm> createAlarm(AlarmInput input) async {
    _check();
    createCalls++;
    return server.putIfAbsent(input.id!, () => _toAlarm(input, version: 1));
  }

  @override
  Future<Alarm> updateAlarm(String id, AlarmInput input) async {
    _check();
    final current = server[id]!;
    if (conflictOnUpdate && input.baseVersion != current.version) {
      throw const AppException('cambió', code: 'version_conflict', status: 409);
    }
    return server[id] = _toAlarm(input, id: id, version: current.version + 1);
  }

  @override
  Future<Alarm> getAlarm(String id) async {
    _check();
    return server[id]!;
  }

  @override
  Future<SyncPayload> sync(int cursor) async {
    _check();
    return SyncPayload(cursor: cursor + 1, serverTime: DateTime.now().toUtc(), alarms: server.values.toList());
  }

  @override
  Future<Map<String, Map<String, bool>>> devicePreferences() async {
    _check();
    return const {};
  }

  Alarm _toAlarm(AlarmInput input, {String? id, required int version}) => Alarm(
        id: id ?? input.id!,
        creator: const PublicUser(id: 'u-me', username: 'yo', displayName: 'Yo'),
        title: input.title,
        localDate: input.localDate,
        localTime: input.localTime,
        timezone: input.timezone,
        scheduledAt: ZonedSchedule.toUtc(input.localDate.at(input.localTime), input.timezone),
        status: AlarmStatus.scheduled,
        priority: input.priority,
        version: version,
        recipients: const [
          AlarmRecipient(
            id: 'r',
            recipientType: RecipientType.user,
            recipientId: 'u-me',
            userId: 'u-me',
            displayName: 'Yo',
            permissionStatus: PermissionStatus.accepted,
            responseStatus: ResponseStatus.noResponse,
          ),
        ],
        nextOccurrenceAt: ZonedSchedule.toUtc(input.localDate.at(input.localTime), input.timezone),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.now().toUtc(),
      );
}

void main() {
  late AppDatabase db;
  late LocalStore store;
  late FakeApi api;
  late SyncEngine engine;
  late AlarmRepository repo;

  AlarmInput input(String title) {
    final tomorrow = LocalDate.fromDateTime(DateTime.now()).addDays(1);
    return AlarmInput(title: title, localDate: tomorrow, localTime: LocalTime(8, 0), timezone: 'America/Bogota');
  }

  setUp(() async {
    ZonedSchedule.ensureInitialized();
    db = AppDatabase(NativeDatabase.memory());
    store = LocalStore(db);
    await store.saveMe(UserProfile(
      id: 'u-me',
      username: 'yo',
      displayName: 'Yo',
      timezone: 'America/Bogota',
      language: 'es',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ));
    api = FakeApi();
    final scheduler = AlarmScheduler(store);
    engine = SyncEngine(api, store, scheduler);
    repo = AlarmRepository(api, store, scheduler);
  });

  tearDown(() => db.close());

  test('sin conexión la alarma se guarda localmente y se envía después', () async {
    api.online = false;
    final outcome = await repo.create(input('Offline'));
    expect(outcome.queued, isTrue);
    expect((await store.alarms()).single.title, 'Offline');
    expect(await store.outbox(), hasLength(1));

    final offline = await engine.sync();
    expect(offline.offline, isTrue);
    expect(api.createCalls, 0);

    api.online = true;
    final result = await engine.sync();
    expect(result.success, isTrue);
    expect(api.createCalls, 1);
    expect(await store.outbox(), isEmpty);
    expect(api.server.keys.single, outcome.value.id);
    expect((await store.alarms()).single.id, outcome.value.id);
  });

  test('editar sin conexión una alarma personal: última edición gana tras un conflicto', () async {
    api.conflictOnUpdate = true;
    final created = (await repo.create(input('V1'))).value;
    // Otro dispositivo la modificó (versión 2 en el servidor).
    api.server[created.id] = api.server[created.id]!.copyForTest(version: 2, title: 'Desde la tablet');

    api.online = false;
    await repo.update(created, input('Desde el teléfono'));
    api.online = true;
    await engine.sync();

    expect(api.server[created.id]!.title, 'Desde el teléfono');
    expect(await store.syncIssues(), isEmpty);
  });

  test('las operaciones rechazadas por el servidor se informan al usuario', () async {
    api.online = false;
    await repo.create(input('Rechazada'));
    api.online = true;
    // Simula que el servidor rechaza la creación (p. ej. destinatario sin permiso).
    final failing = _RejectingApi();
    final engine2 = SyncEngine(failing, store, AlarmScheduler(store));
    await engine2.sync();
    expect(await store.outbox(), isEmpty);
    expect((await store.syncIssues()).single, contains('No se pudo crear «Rechazada»'));
    expect(await store.alarms(), isEmpty);
  });
}

class _RejectingApi extends FakeApi {
  @override
  Future<Alarm> createAlarm(AlarmInput input) async =>
      throw const AppException('Solo puedes enviar alarmas a tus contactos.', status: 403);
}

extension on Alarm {
  Alarm copyForTest({required int version, required String title}) => Alarm(
        id: id,
        creator: creator,
        title: title,
        localDate: localDate,
        localTime: localTime,
        timezone: timezone,
        scheduledAt: scheduledAt,
        status: status,
        priority: priority,
        version: version,
        recipients: recipients,
        nextOccurrenceAt: nextOccurrenceAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
