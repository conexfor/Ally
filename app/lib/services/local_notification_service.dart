import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ally_core/ally_core.dart';

/// Notificaciones informativas (nueva alarma recibida, solicitudes, respuestas).
/// Las alarmas que suenan las gestiona [AlarmScheduler].
class LocalNotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Ruta a abrir al tocar una notificación.
  void Function(String route)? onOpenRoute;

  static const _channel = AndroidNotificationChannel(
    'ally_updates',
    'Novedades',
    description: 'Alarmas recibidas, solicitudes de conexión y respuestas.',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) onOpenRoute?.call(route);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    _initialized = true;
  }

  /// Ruta que abrió la app desde una notificación (si la cerró el sistema).
  Future<String?> launchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details!.notificationResponse?.payload;
  }

  /// Pide los permisos necesarios: notificaciones, alarmas exactas y
  /// pantalla completa (Android 13/12/14). Devuelve si se concedieron.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notifications = await android?.requestNotificationsPermission() ?? true;
      if (await android?.canScheduleExactNotifications() == false) {
        await android?.requestExactAlarmsPermission();
      }
      await android?.requestFullScreenIntentPermission();
      return notifications;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true, critical: false) ?? false;
  }

  /// ¿Puede la app mostrar notificaciones? Sin ellas Android descarta la
  /// pantalla de la alarma (va dentro de una notificación) y los avisos.
  Future<bool> notificationsEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ??
        true;
  }

  /// Pide solo el permiso de notificaciones (sin abrir otros ajustes). Si ya se
  /// negó antes, Android no vuelve a preguntar y devuelve `false`.
  Future<bool> requestNotificationsPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
  }

  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        true;
  }

  Future<void> show({required String id, required String title, required String body, String? route}) async {
    if (!_initialized) await init();
    await _plugin.show(
      id: id.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      payload: route,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'notification_icon',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showFor(AppNotification n) =>
      show(id: n.id, title: n.title, body: n.body, route: routeFor(n.type, n.alarmId, n.data));

  /// Pantalla a abrir para cada tipo de notificación.
  static String routeFor(NotificationType type, String? alarmId, Map<String, dynamic> data) => switch (type) {
        NotificationType.connectionRequest => '/contacts/requests',
        NotificationType.connectionAccepted => '/people',
        NotificationType.groupInvitation =>
          data['group_id'] == null ? '/people' : '/groups/${data['group_id']}',
        _ => alarmId == null ? '/notifications' : '/alarms/$alarmId',
      };
}
