import 'dart:async';
import 'dart:ui';

import 'package:alarm/alarm.dart' as native;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:ally_core/ally_core.dart';

import '../app/app_services.dart';
import '../core/config/env.dart';
import 'local_notification_service.dart';

FirebaseOptions get _firebaseOptions => const FirebaseOptions(
      apiKey: Env.firebaseApiKey,
      appId: Env.firebaseAppId,
      messagingSenderId: Env.firebaseSenderId,
      projectId: Env.firebaseProjectId,
    );

/// Mensajes que llegan con la app cerrada o en segundo plano: sincroniza,
/// reprograma las alarmas locales y muestra el aviso.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: _firebaseOptions);
  // Los eventos de las notificaciones se confirman tras guardarlos
  // (AlarmEventHandler), para no perderlos si la app se cierra.
  await native.Alarm.init(acknowledgeEventsAutomatically: false);
  final services = await AppServices.create();
  try {
    if (!services.tokens.hasSession) return;
    await services.sync.sync();
    await PushService.showIfNeeded(services.notifications, message.data);
  } finally {
    await services.database.close();
  }
}

/// Notificaciones push (Firebase Cloud Messaging). Si Firebase no está
/// configurado, la app funciona igual: sincroniza al abrirse y cada pocos
/// minutos mientras está abierta.
class PushService {
  final AppServices services;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _enabled = false;

  PushService(this.services);

  bool get enabled => _enabled;

  Future<void> init({required void Function(String route) onOpenRoute}) async {
    if (!Env.firebaseConfigured || kIsWeb) return;
    try {
      await Firebase.initializeApp(options: _firebaseOptions);
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      await services.devices.register(pushToken: token);
      _subscriptions
        ..add(messaging.onTokenRefresh.listen((t) => services.devices.register(pushToken: t)))
        ..add(FirebaseMessaging.onMessage.listen((m) async {
          await services.sync.sync();
          await showIfNeeded(services.notifications, m.data);
        }))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpenRoute(_routeFor(m.data))));
      final initial = await messaging.getInitialMessage();
      if (initial != null) onOpenRoute(_routeFor(initial.data));
      _enabled = true;
    } catch (e) {
      debugPrint('Push no disponible: $e');
    }
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
  }

  /// Los mensajes de alarmas llegan "solo datos": la app muestra el aviso.
  static Future<void> showIfNeeded(LocalNotificationService notifications, Map<String, dynamic> data) async {
    final typeWire = data['type'] as String?;
    if (typeWire == null || data['silent'] == 'true') return;
    final NotificationType type;
    try {
      type = NotificationType.fromWire(typeWire);
    } catch (_) {
      return;
    }
    if (type == NotificationType.syncRequired) return;
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;
    await notifications.show(
      id: '${data['alarm_id'] ?? ''}:$typeWire:${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      title: title,
      body: body,
      route: LocalNotificationService.routeFor(type, data['alarm_id'] as String?, data),
    );
  }

  static String _routeFor(Map<String, dynamic> data) {
    try {
      return LocalNotificationService.routeFor(
        NotificationType.fromWire(data['type'] as String? ?? ''),
        data['alarm_id'] as String?,
        data,
      );
    } catch (_) {
      return '/notifications';
    }
  }
}
