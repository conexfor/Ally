import 'model/command_draft.dart';
import 'model/interpretation_context.dart';
import 'model/interpretation_result.dart';

/// Contrato de cualquier intérprete de comandos del asistente.
///
/// La implementación actual es `RuleBasedCommandInterpreter` (reglas,
/// expresiones regulares y diccionarios; sin IA). La interfaz es asíncrona
/// para que en el futuro pueda añadirse otra implementación (por ejemplo,
/// un intérprete basado en IA opcional) sin cambiar a quienes la usan.
abstract interface class CommandInterpreter {
  /// Interpreta un texto nuevo del usuario.
  Future<InterpretationResult> interpret(
    String text,
    InterpretationContext context,
  );

  /// Aplica la opción elegida por el usuario a un borrador pendiente.
  Future<InterpretationResult> applyOption(
    CommandDraft draft,
    ClarificationOption option,
    InterpretationContext context,
  );

  /// Responde con texto libre a la aclaración pendiente de [pending]. Si el
  /// texto parece un comando nuevo, se interpreta como tal.
  Future<InterpretationResult> answer(
    InterpretationResult pending,
    String text,
    InterpretationContext context,
  );

  /// Vuelve a evaluar un borrador (p. ej. tras editarlo en un formulario).
  Future<InterpretationResult> evaluate(
    CommandDraft draft,
    InterpretationContext context,
  );
}
