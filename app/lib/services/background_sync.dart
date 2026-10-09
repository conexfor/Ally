import 'package:alarm/alarm.dart' as native;
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../app/app_services.dart';

const _periodicTask = 'ally.periodic-sync';

/// Punto de entrada del isolate de WorkManager.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      // Los eventos de las notificaciones se dejan para la app (los confirma
      // AlarmEventHandler tras guardarlos).
      await native.Alarm.init(acknowledgeEventsAutomatically: false);
      final services = await AppServices.create();
      try {
        if (services.tokens.hasSession) await services.sync.sync();
      } finally {
        await services.database.close();
      }
      return true;
    } catch (e) {
      debugPrint('Sincronización en segundo plano: $e');
      return false;
    }
  });
}

/// Sincronización periódica con la app cerrada (Android, cada ~15 min con
/// red). Complementa a los avisos push: si no hay Firebase o un push se
/// pierde, las alarmas nuevas igualmente se programan en el teléfono.
abstract final class BackgroundSync {
  static Future<void> register() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().initialize(backgroundSyncDispatcher);
      await Workmanager().registerPeriodicTask(
        _periodicTask,
        _periodicTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('No se pudo programar la sincronización en segundo plano: $e');
    }
  }

  static Future<void> cancel() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().cancelByUniqueName(_periodicTask);
    } catch (_) {}
  }
}
