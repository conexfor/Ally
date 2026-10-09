import 'package:alarm/alarm.dart' as native;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';

import '../application/assistant/command_executor.dart';
import '../application/assistant/context_builder.dart';
import '../services/alarm_scheduler.dart';
import 'app_services.dart';

/// Se sobrescribe en `main` con la instancia creada al arrancar.
final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('AppServices no inicializado'),
);

final interpreterProvider = Provider<CommandInterpreter>((ref) => RuleBasedCommandInterpreter());

final contextBuilderProvider = Provider(
  (ref) => InterpretationContextBuilder(ref.watch(appServicesProvider).store),
);

final commandExecutorProvider = Provider((ref) {
  final s = ref.watch(appServicesProvider);
  return CommandExecutor(s.alarms, s.social, s.store);
});

// ------------------------------------------------------------------- datos

final meProvider = StreamProvider<UserProfile?>((ref) => ref.watch(appServicesProvider).store.watchMe());

final settingsProvider = StreamProvider<UserSettings>(
  (ref) => ref.watch(appServicesProvider).store.watchSettings(),
);

final alarmsProvider = StreamProvider<List<Alarm>>((ref) => ref.watch(appServicesProvider).store.watchAlarms());

final alarmProvider = StreamProvider.family<Alarm?, String>(
  (ref, id) => ref.watch(appServicesProvider).store.watchAlarm(id),
);

final alarmResponsesProvider = StreamProvider.family<List<AlarmResponse>, String>(
  (ref, id) => ref.watch(appServicesProvider).store.watchResponses(id),
);

final contactsProvider = StreamProvider<List<Contact>>(
  (ref) => ref.watch(appServicesProvider).store.watchContacts(),
);

final groupsProvider = StreamProvider<List<Group>>(
  (ref) => ref.watch(appServicesProvider).store.watchGroups(),
);

/// Notificaciones locales; el parámetro es cuántas mostrar (paginación).
final notificationsProvider = StreamProvider.family<List<AppNotification>, int>(
  (ref, limit) => ref.watch(appServicesProvider).store.watchNotifications(limit: limit),
);

final unreadCountProvider = StreamProvider<int>(
  (ref) => ref.watch(appServicesProvider).store.watchUnreadCount(),
);

final pendingOutboxProvider = StreamProvider<int>(
  (ref) => ref.watch(appServicesProvider).store.watchOutboxCount(),
);

final lastSyncProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(appServicesProvider).store.watchLastSync(),
);

final syncIssuesProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(appServicesProvider).store.watchSyncIssues(),
);

// ------------------------------------------------------- alarmas sonando

class RingingAlarm {
  final int nativeId;
  final String alarmId;
  final DateTime occurrenceAt;
  final String title;
  final String body;

  const RingingAlarm(this.nativeId, this.alarmId, this.occurrenceAt, this.title, this.body);
}

/// Alarmas que están sonando ahora mismo en este dispositivo.
final ringingProvider = StreamProvider<List<RingingAlarm>>((ref) {
  return native.Alarm.ringing.map((set) => [
        for (final settings in set.alarms)
          if (RingPayload.decode(settings.payload) case final payload?)
            RingingAlarm(
              settings.id,
              payload.alarmId,
              payload.occurrenceAt,
              settings.notificationSettings.title,
              settings.notificationSettings.body,
            ),
      ]);
});
