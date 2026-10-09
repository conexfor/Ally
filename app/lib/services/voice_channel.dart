import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Estado del asistente por voz en este dispositivo.
class VoiceStatus {
  /// «Hey Ally» activado por el usuario.
  final bool enabled;

  /// El servicio está escuchando ahora mismo.
  final bool running;

  /// Está empaquetado el modelo `assets/wakeword/hey_ally.onnx`.
  final bool modelAvailable;
  final bool micPermission;

  /// El teléfono tiene un reconocedor de voz (Google, Samsung...).
  final bool recognitionAvailable;

  /// Permiso «Mostrar sobre otras apps»: burbuja «Te escucho…» en vez de
  /// notificación.
  final bool overlayPermission;

  const VoiceStatus({
    this.enabled = false,
    this.running = false,
    this.modelAvailable = false,
    this.micPermission = false,
    this.recognitionAvailable = false,
    this.overlayPermission = false,
  });

  factory VoiceStatus.fromMap(Map<Object?, Object?>? map) => VoiceStatus(
        enabled: map?['enabled'] == true,
        running: map?['running'] == true,
        modelAvailable: map?['model_available'] == true,
        micPermission: map?['mic_permission'] == true,
        recognitionAvailable: map?['recognition_available'] == true,
        overlayPermission: map?['overlay_permission'] == true,
      );
}

/// Puente con la parte nativa de voz (android/.../voice). Por ahora solo
/// Android: iOS no permite escuchar una palabra clave en segundo plano.
abstract final class VoiceChannel {
  static const _channel = MethodChannel('ally/voice');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<VoiceStatus> status() async {
    if (!isSupported) return const VoiceStatus();
    return VoiceStatus.fromMap(await _channel.invokeMethod<Map<Object?, Object?>>('status'));
  }

  /// Activa o desactiva «Hey Ally» (pide el permiso de micrófono).
  static Future<VoiceStatus> setWakeWordEnabled(bool enabled) async {
    if (!isSupported) return const VoiceStatus();
    return VoiceStatus.fromMap(
      await _channel.invokeMethod<Map<Object?, Object?>>('setWakeWordEnabled', enabled),
    );
  }

  /// Escucha una frase y devuelve el texto, o `null` si no se oyó nada.
  /// Lanza [PlatformException] (`permission`) si se niega el micrófono.
  static Future<String?> listen() => _channel.invokeMethod<String>('listen');

  static Future<void> stopListening() => _channel.invokeMethod('stopListening');

  /// Lee [text] en voz alta; termina cuando acaba de hablar.
  static Future<void> speak(String text) => _channel.invokeMethod('speak', text);

  /// Abre los ajustes del permiso «Mostrar sobre otras apps».
  static Future<void> requestOverlayPermission() => _channel.invokeMethod('requestOverlayPermission');

  static Future<void> stopSpeaking() => _channel.invokeMethod('stopSpeaking');
}
