import 'package:ally_core/ally_core.dart';

import '../core/config/env.dart';
import '../data/local/app_database.dart';
import '../data/local/local_store.dart';
import '../data/remote/api_client.dart';
import '../data/remote/ally_api.dart';
import '../data/remote/token_store.dart';
import '../data/repositories/alarm_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/social_repository.dart';
import '../services/alarm_scheduler.dart';
import '../services/device_service.dart';
import '../services/local_notification_service.dart';
import '../services/sync_engine.dart';

/// Contenedor de dependencias (sin Flutter widgets), usable también desde
/// el isolate de mensajes push en segundo plano.
class AppServices {
  final AppDatabase database;
  final LocalStore store;
  final TokenStore tokens;
  final ApiClient client;
  final AllyApi api;
  final AlarmScheduler scheduler;
  final SyncEngine sync;
  final AuthRepository auth;
  final AlarmRepository alarms;
  final SocialRepository social;
  final DeviceService devices;
  final LocalNotificationService notifications;

  AppServices._({
    required this.database,
    required this.store,
    required this.tokens,
    required this.client,
    required this.api,
    required this.scheduler,
    required this.sync,
    required this.auth,
    required this.alarms,
    required this.social,
    required this.devices,
    required this.notifications,
  });

  static Future<AppServices> create({AppDatabase? database}) async {
    ZonedSchedule.ensureInitialized();
    final db = database ?? AppDatabase();
    final store = LocalStore(db);
    final tokens = TokenStore();
    await tokens.load();
    final client = ApiClient(baseUrl: Env.apiBaseUrl, tokens: tokens);
    final api = AllyApi(client);
    final scheduler = AlarmScheduler(store);
    final services = AppServices._(
      database: db,
      store: store,
      tokens: tokens,
      client: client,
      api: api,
      scheduler: scheduler,
      sync: SyncEngine(api, store, scheduler),
      auth: AuthRepository(api, tokens, store, scheduler),
      alarms: AlarmRepository(api, store, scheduler),
      social: SocialRepository(api, store),
      devices: DeviceService(api, client, store),
      notifications: LocalNotificationService(),
    );
    await services.devices.restore();
    return services;
  }
}
