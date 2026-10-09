import 'package:alarm/alarm.dart' as native;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/providers.dart';
import 'services/voice_entrypoint.dart';

Future<void> main() async {
  final reloj = Stopwatch()..start();
  void marca(String paso) => debugPrint('AllyInicio ${reloj.elapsedMilliseconds} ms: $paso');
  // Una sola pantalla de carga: la de Android solo muestra el fondo (sin icono)
  // y la de la app (SplashScreen) aparece en cuanto se dibuja el primer fotograma.
  WidgetsFlutterBinding.ensureInitialized();
  // En paralelo: no dependen uno del otro. Los eventos de las notificaciones
  // se confirman tras guardarlos (AlarmEventHandler), para no perderlos.
  final (_, services) = await (
    _initAlarmPlugin(),
    AppServices.create(),
  ).wait;
  marca('plugin de alarmas y servicios');
  try {
    await services.notifications.init().timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('AllyInicio notificaciones no disponibles: $e');
  }
  marca('notificaciones');

  runApp(ProviderScope(
    overrides: [appServicesProvider.overrideWithValue(services)],
    child: const AllyApp(),
  ));
}

/// Al reabrir la app con el proceso aún vivo (p. ej. por «Hey Ally») el plugin
/// de alarmas a veces no responde: sin límite, la app se quedaba para siempre
/// en la pantalla de arranque. Se sigue sin él; la app reprograma al sincronizar.
Future<void> _initAlarmPlugin() async {
  try {
    await native.Alarm.init(acknowledgeEventsAutomatically: false).timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('AllyInicio plugin de alarmas no disponible: $e');
  }
}

/// Punto de entrada del asistente por voz sin interfaz («Hey Ally»), que lanza
/// el servicio de Android (VoiceSession.kt). Tiene que estar en este archivo:
/// Flutter solo garantiza que la biblioteca principal llegue al código compilado.
@pragma('vm:entry-point')
Future<void> voiceAssistantMain() => runVoiceAssistant();
