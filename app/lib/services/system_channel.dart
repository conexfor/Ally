import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Acciones del sistema Android que no cubre ningún plugin (MainActivity.kt).
abstract final class SystemChannel {
  static const _channel = MethodChannel('ally/system');

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Abre los ajustes de notificaciones de la app.
  static Future<void> openNotificationSettings() async {
    if (_android) await _channel.invokeMethod('openNotificationSettings');
  }

  /// Manda la app al fondo sin cerrarla (vuelve a la pantalla anterior).
  static Future<void> moveToBackground() async {
    if (_android) await _channel.invokeMethod('moveToBackground');
  }
}
