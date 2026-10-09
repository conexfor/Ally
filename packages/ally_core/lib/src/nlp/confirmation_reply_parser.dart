import 'text_normalizer.dart';

enum ConfirmationReply { confirm, reject, unknown }

/// Interpreta respuestas cortas a una confirmación: "sí", "dale", "confirmar",
/// "no", "cancelar", "mejor no"...
class ConfirmationReplyParser {
  const ConfirmationReplyParser();

  static final _yes = RegExp(
    r'^(?:si|sip|claro|dale|ok|okay|okey|vale|confirmar?|confirmo|correcto|'
    r'adelante|hazlo|perfecto|listo|de acuerdo|por supuesto|exacto|eso es|'
    r'si por favor|si gracias|crear?la|crealo|yes)$',
  );
  static final _no = RegExp(
    r'^(?:no|nop|nope|cancelar?|cancela|mejor no|olvidalo|dejalo|nada|'
    r'no gracias|no por favor|para|detente|no la crees|no lo hagas)$',
  );

  ConfirmationReply parse(String text) {
    final key = TextNormalizer.foldWithSameLength(text)
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (_yes.hasMatch(key)) return ConfirmationReply.confirm;
    if (_no.hasMatch(key)) return ConfirmationReply.reject;
    return ConfirmationReply.unknown;
  }
}
