import 'package:flutter/foundation.dart';
import 'package:ally_core/ally_core.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../services/device_service.dart';
import 'chat_controller.dart';
import 'command_executor.dart';
import 'context_builder.dart';
import 'voice_policy.dart';

/// Respuesta de un turno de voz.
class VoiceTurn {
  /// Texto a leer en voz alta.
  final String speech;

  /// El asistente hizo una pregunta: hay que volver a escuchar.
  final bool expectsAnswer;

  const VoiceTurn(this.speech, {this.expectsAnswer = false});

  Map<String, Object> toMap() => {'reply': speech, 'expects_answer': expectsAnswer};
}

/// Conversación por voz con la app cerrada («Hey Ally»). Usa el mismo
/// intérprete y ejecutor que el chat, y guarda los mensajes en su historial.
class VoiceAssistant {
  static const _uuid = Uuid();

  final CommandInterpreter interpreter;
  final InterpretationContextBuilder contextBuilder;
  final CommandExecutor executor;
  final ChatHistory history;

  InterpretationResult? _pending;

  VoiceAssistant({
    required this.interpreter,
    required this.contextBuilder,
    required this.executor,
    required this.history,
  });

  Future<VoiceTurn> handle(String rawText) async {
    final text = rawText.trim();
    await _log(ChatRole.user, text);
    try {
      final pending = _pending;
      if (pending?.status == InterpretationStatus.needsConfirmation) {
        switch (const ConfirmationReplyParser().parse(text)) {
          case ConfirmationReply.confirm:
            return await _execute(pending!);
          case ConfirmationReply.reject:
            return await _end('Cancelado.');
          case ConfirmationReply.unknown:
            break;
        }
      }
      final ctx = await contextBuilder.build(timezone: await DeviceService.currentTimezone());
      final result = pending?.status == InterpretationStatus.needsClarification
          ? await interpreter.answer(pending!, text, ctx)
          : await interpreter.interpret(text, ctx);
      debugPrint('AllyVoice[dart] interpretado: ${result.status.wire} ${result.draft.date} ${result.draft.time}');
      return await _handle(result);
    } catch (e) {
      return _end(userMessage(e));
    }
  }

  Future<VoiceTurn> _handle(InterpretationResult result) async {
    if (VoicePolicy.autoExecutes(result) || result.status == InterpretationStatus.readyToExecute) {
      await _log(ChatRole.system, result.reply, interpretation: result);
      return _execute(result);
    }
    switch (result.status) {
      case InterpretationStatus.needsConfirmation:
      case InterpretationStatus.needsClarification:
        _pending = result;
        await _log(ChatRole.system, result.reply, interpretation: result);
        return VoiceTurn(VoicePolicy.speech(result), expectsAnswer: true);
      case InterpretationStatus.readyToExecute:
      case InterpretationStatus.invalid:
      case InterpretationStatus.notUnderstood:
        return _end(result.reply);
    }
  }

  Future<VoiceTurn> _execute(InterpretationResult result) async {
    _pending = null;
    final ExecutionResult outcome;
    try {
      debugPrint('AllyVoice[dart] ejecutando ${result.draft.intent.name}');
      outcome = await executor.execute(result.draft);
      debugPrint('AllyVoice[dart] ejecutado');
    } catch (e) {
      return _end(e is AppException ? e.message : 'No pude completar la acción. Inténtalo de nuevo.');
    }
    await _log(ChatRole.system, outcome.reply, route: outcome.route, routeLabel: outcome.routeLabel);
    return VoiceTurn(
      result.draft.intent == CommandIntent.createAlarm && result.confirmation != null
          ? VoicePolicy.created(result, outcome.reply)
          : VoicePolicy.clean(outcome.reply),
    );
  }

  Future<VoiceTurn> _end(String reply) async {
    _pending = null;
    await _log(ChatRole.system, reply);
    return VoiceTurn(VoicePolicy.clean(reply));
  }

  Future<void> _log(
    ChatRole role,
    String text, {
    InterpretationResult? interpretation,
    String? route,
    String? routeLabel,
  }) async {
    try {
      await history.save([
        ChatItem(
          id: _uuid.v4(),
          role: role,
          text: text,
          at: DateTime.now().toUtc(),
          interpretation: interpretation,
          route: route,
          routeLabel: routeLabel,
        ),
      ]);
    } catch (_) {
      // El historial es secundario: nunca impide ejecutar la orden.
    }
  }
}
