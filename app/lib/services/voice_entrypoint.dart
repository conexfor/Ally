import 'dart:async';
import 'dart:ui';

import 'package:alarm/alarm.dart' as native;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ally_core/ally_core.dart';

import '../app/app_services.dart';
import '../application/assistant/chat_controller.dart';
import '../application/assistant/command_executor.dart';
import '../application/assistant/context_builder.dart';
import '../application/assistant/voice_assistant.dart';

/// Asistente por voz en el motor Flutter sin interfaz que lanza el servicio de
/// Android al oír «Hey Ally» (ver `voiceAssistantMain` en main.dart). Recibe lo
/// que dijo el usuario y devuelve el texto a leer.
///
/// Cada paso tiene un tiempo máximo y deja rastro en Logcat (`AllyVoice[dart]`),
/// para que nunca se quede esperando en silencio.
Future<void> runVoiceAssistant() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  const channel = MethodChannel('ally/voice_session');
  final reloj = Stopwatch()..start();
  void log(String mensaje) => debugPrint('AllyVoice[dart] ${reloj.elapsedMilliseconds} ms: $mensaje');

  AppServices? services;
  // Se prepara en paralelo a la escucha; `handle` espera a que termine.
  final preparado = () async {
    try {
      // Los eventos de las notificaciones se dejan para la app. Si el plugin de
      // alarmas tarda (p. ej. una alarma sonando sin responder), se sigue sin
      // él: la alarma se guarda igual y la app la programa al sincronizar.
      await native.Alarm.init(acknowledgeEventsAutomatically: false).timeout(const Duration(seconds: 4));
      log('plugin de alarmas listo');
    } catch (e) {
      log('plugin de alarmas no disponible: $e');
    }
    services = await AppServices.create().timeout(const Duration(seconds: 8));
    log('servicios listos');
    final s = services!;
    // Por voz se responde enseguida: si el servidor tarda, la alarma se guarda
    // y programa en el teléfono y se envía después.
    s.alarms.serverTimeout = const Duration(seconds: 5);
    if (!s.tokens.hasSession || await s.store.me() == null) {
      log('sin sesión');
      return null;
    }
    return VoiceAssistant(
      interpreter: RuleBasedCommandInterpreter(),
      contextBuilder: InterpretationContextBuilder(s.store),
      executor: CommandExecutor(s.alarms, s.social, s.store),
      history: ChatHistory(s.store),
    );
  }();

  // Envío de lo que quedó en cola mientras se lee la respuesta.
  Future<void>? enviando;

  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'handle':
        final text = call.arguments as String;
        log('recibido: $text');
        try {
          final assistant = await preparado.timeout(const Duration(seconds: 12));
          if (assistant == null) {
            return const VoiceTurn('Abre Ally e inicia sesión para usar la voz.').toMap();
          }
          final turn = await assistant.handle(text).timeout(const Duration(seconds: 15));
          log('respuesta: ${turn.speech}');
          final s = services;
          if (s != null) {
            enviando = s.sync.sync().then(
              (_) => log('sincronizado'),
              onError: (Object e) => log('sin sincronizar: $e'),
            );
          }
          return turn.toMap();
        } on TimeoutException catch (e) {
          log('tiempo agotado: $e');
          return const VoiceTurn('No pude completar la acción a tiempo. Inténtalo de nuevo.').toMap();
        } catch (e) {
          log('error: $e');
          return const VoiceTurn('No pude completar la acción. Inténtalo de nuevo desde la app.').toMap();
        }
      case 'end':
        // Lo que no alcance a enviarse lo envía la app al abrirse o en segundo plano.
        await enviando?.timeout(const Duration(seconds: 6), onTimeout: () => log('envío pendiente'));
        await services?.database.close();
        return null;
    }
    return null;
  });
  // Listo para recibir órdenes mientras se termina de preparar.
  await channel.invokeMethod('ready');
  log('motor listo');
}
