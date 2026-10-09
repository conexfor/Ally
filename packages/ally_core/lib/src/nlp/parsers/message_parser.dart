import '../lexicon/message_lexicon.dart';
import '../parse_state.dart';

class MessageExtraction {
  final String text;
  final bool quoted;
  const MessageExtraction(this.text, {required this.quoted});
}

/// Regla de extracción: el grupo 1 del patrón es el contenido y llega hasta el
/// final de la coincidencia.
class _MessageRule {
  final RegExp pattern;

  /// Si se consume también lo anterior al contenido (el marcador). En los
  /// recordatorios ("recuérdale a Juan que ...") no se consume, porque ahí
  /// están el verbo y el destinatario.
  final bool consumeMarker;

  const _MessageRule(this.pattern, {required this.consumeMarker});
}

/// Extrae el mensaje de la alarma.
///
/// Se ejecuta antes que el resto de parsers porque el mensaje es texto libre
/// que podría contener palabras como "mañana" o "cancelar".
///
/// Admite:
/// - texto entre comillas: `que diga "Reunión de proyecto"`;
/// - marcadores: `que diga ...`, `con el mensaje ...`, `título: ...`;
/// - recordatorios: `recuérdale a Juan que llame al médico`,
///   `recuérdame tomar la pastilla`.
///
/// Si el mensaje no va entre comillas y termina con información de fecha u
/// hora ("que diga reunión mañana a las 8"), esa cola se devuelve al resto de
/// parsers gracias a [isSchedulingTail].
class MessageParser {
  /// Indica si un fragmento (normalizado) contiene solo fecha/hora/recurrencia.
  final bool Function(String normalizedTail) isSchedulingTail;

  MessageParser({required this.isSchedulingTail});

  static final _rules = [
    _MessageRule(
      RegExp('\\b(?:${messageMarkers.join('|')})\\s*:?\\s*([^|]+)'),
      consumeMarker: true,
    ),
    _MessageRule(
      RegExp('$reminderVerbsPattern[^|]*?\\bque\\s+([^|]+)'),
      consumeMarker: false,
    ),
    // El infinitivo puede ir tras la fecha/hora: "recuérdame mañana a las 4
    // tomar la pastilla". Se excluyen sustantivos frecuentes terminados en
    // -ar/-er/-ir y las palabras precedidas de "a"/"para" ("a Javier").
    _MessageRule(
      RegExp(
        r'\b(?:recuerdame|recordarme|avisame|recuerdale|recuerdales|avisale|avisales)\b[^|]*?\s(?:de\s+)?'
        r'(?<!\b(?:a|al|para|y|e|con)\s)'
        r'((?!(?:ayer|lugar|hogar|mujer|taller|bar|mar|par|solar|altar|mayor|menor|mejor|peor)\b)'
        r'[a-z]{2,}(?:ar|er|ir)(?:me|te|se|le|lo|la|nos)?\b[^|]*)',
      ),
      consumeMarker: false,
    ),
  ];

  MessageExtraction? extract(ParseState state) {
    final quoted = _extractQuoted(state);
    if (quoted != null) return quoted;
    for (final rule in _rules) {
      final result = _extractWith(state, rule);
      if (result != null) return result;
    }
    return null;
  }

  MessageExtraction? _extractQuoted(ParseState state) {
    final text = state.available;
    for (final pair in quotePairs.entries) {
      final open = RegExp.escape(pair.key);
      final close = RegExp.escape(pair.value);
      // Incluye un marcador opcional delante ("que diga", "con el mensaje").
      final pattern = RegExp(
        '(?:\\b(?:${messageMarkers.join('|')})\\s*:?\\s*)?$open([^$close|]{1,$maxMessageLength})$close',
      );
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final contentEnd = match.end - 1;
      final contentStart = contentEnd - match[1]!.length;
      final content = state.originalSlice(contentStart, contentEnd).trim();
      if (content.isEmpty) continue;
      state.consumeMatch(match);
      return MessageExtraction(_tidy(content), quoted: true);
    }
    return null;
  }

  MessageExtraction? _extractWith(ParseState state, _MessageRule rule) {
    final match = rule.pattern.firstMatch(state.available);
    if (match == null) return null;

    final contentStart = match.end - match[1]!.length;
    final contentEnd = _trimSchedulingTail(state, contentStart, match.end);

    final content = _tidy(state.originalSlice(contentStart, contentEnd));
    if (content.isEmpty) return null;

    // En recordatorios se consume desde el "que" (si lo hay), no el verbo.
    var consumeFrom = match.start;
    if (!rule.consumeMarker) {
      final before = state.normalized.substring(match.start, contentStart);
      final que = RegExp(r'\bque\s+$').firstMatch(before);
      consumeFrom = que == null ? contentStart : match.start + que.start;
    }
    state.consume(consumeFrom, contentEnd);
    return MessageExtraction(content, quoted: false);
  }

  /// Devuelve la posición donde termina el mensaje, recortando una cola que
  /// solo contenga fecha/hora ("... mañana a las 8").
  int _trimSchedulingTail(ParseState state, int start, int end) {
    final normalized = state.normalized;
    final wordStarts = RegExp(r'(?<=\s)\S')
        .allMatches(normalized.substring(0, end), start + 1)
        .map((m) => m.start);
    for (final position in wordStarts) {
      final tail = normalized.substring(position, end);
      if (isSchedulingTail(tail)) return position;
    }
    return end;
  }

  static String _tidy(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^[:\s"“«]+|[\s.,;!?"”»]+$'), '');
    if (text.length > maxMessageLength) {
      text = text.substring(0, maxMessageLength).trimRight();
    }
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
