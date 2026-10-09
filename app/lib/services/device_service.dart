import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ally_core/ally_core.dart';

import '../core/errors/app_exception.dart';
import '../data/local/local_store.dart';
import '../data/remote/api_client.dart';
import '../data/remote/ally_api.dart';

/// Identidad de este dispositivo ante el servidor (nombre, zona horaria y
/// token de push).
class DeviceService {
  final AllyApi api;
  final ApiClient client;
  final LocalStore store;

  DeviceService(this.api, this.client, this.store);

  static Future<String> currentTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return ZonedSchedule.isValidTimezone(info.identifier) ? info.identifier : 'UTC';
    } catch (_) {
      return 'UTC';
    }
  }

  /// Carga el ID del dispositivo guardado para enviarlo en cada petición.
  Future<void> restore() async {
    client.deviceId = (await store.device())?.id;
  }

  /// Registra o actualiza el dispositivo. Sin conexión no hace nada (se
  /// reintentará en la próxima apertura).
  Future<Device?> register({String? pushToken}) async {
    final existing = await store.device();
    try {
      final device = await api.registerDevice(DeviceInput(
        id: existing?.id,
        deviceName: existing?.deviceName ?? await _defaultName(),
        deviceType: _deviceType(),
        platform: _platform(),
        pushToken: pushToken,
        timezone: await currentTimezone(),
        appVersion: await _appVersion(),
      ));
      await store.saveDevice(device);
      client.deviceId = device.id;
      return device;
    } on AppException catch (e) {
      if (!e.isNetwork) debugPrint('No se pudo registrar el dispositivo: $e');
      return existing;
    }
  }

  Future<Device> rename(String name) async {
    final device = (await store.device())!;
    final updated = await api.updateDevice(device.id, name: name);
    await store.saveDevice(updated);
    return updated;
  }

  Future<Device> setReceivesAlarms(Device device, bool value) async {
    final updated = await api.updateDevice(device.id, receivesAlarms: value);
    final current = await store.device();
    if (current?.id == updated.id) await store.saveDevice(updated);
    return updated;
  }

  /// Tablet si el lado corto de la pantalla mide 600 dp o más (criterio de
  /// Android para tablets).
  static DeviceType _deviceType() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return DeviceType.phone;
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    return size.shortestSide >= 600 ? DeviceType.tablet : DeviceType.phone;
  }

  static DevicePlatform _platform() {
    if (kIsWeb) return DevicePlatform.web;
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isIOS) return DevicePlatform.ios;
    return DevicePlatform.other;
  }

  static Future<String> _defaultName() async {
    try {
      final info = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final android = await info.androidInfo;
        return _limit('${android.manufacturer} ${android.model}'.trim());
      }
      if (!kIsWeb && Platform.isIOS) {
        return _limit((await info.iosInfo).name);
      }
    } catch (_) {}
    return 'Mi teléfono';
  }

  static String _limit(String name) {
    if (name.isEmpty) return 'Mi teléfono';
    final capitalized = name[0].toUpperCase() + name.substring(1);
    return capitalized.length > 60 ? capitalized.substring(0, 60) : capitalized;
  }

  static Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}
