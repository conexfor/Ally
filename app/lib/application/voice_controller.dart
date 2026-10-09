import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/voice_channel.dart';

/// Estado de «Hey Ally» (pantalla de configuración).
class VoiceWakeController extends AsyncNotifier<VoiceStatus> {
  @override
  Future<VoiceStatus> build() => VoiceChannel.status();

  /// Activa o desactiva la escucha; al activar se pide el micrófono.
  Future<VoiceStatus> setEnabled(bool enabled) async {
    final status = await VoiceChannel.setWakeWordEnabled(enabled);
    state = AsyncData(status);
    return status;
  }
}

/// Se vuelve a consultar cada vez que se abre Configuración.
final voiceWakeProvider = AsyncNotifierProvider.autoDispose<VoiceWakeController, VoiceStatus>(
  VoiceWakeController.new,
);
