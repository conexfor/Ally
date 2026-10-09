import 'text_normalizer.dart';

/// Fragmento del texto reconocido por un parser.
class TextSpan {
  final int start;
  final int end;
  const TextSpan(this.start, this.end);

  int get length => end - start;

  @override
  String toString() => '[$start,$end)';
}

/// Estado compartido por los parsers durante un análisis.
///
/// Cada parser "consume" los fragmentos que reconoce: se sustituyen por el
/// marcador `|` en [available], de modo que los parsers siguientes no los
/// vuelvan a interpretar (p. ej. "de la mañana" consumido como franja horaria
/// ya no puede leerse como la fecha "mañana").
class ParseState {
  final NormalizedText text;
  final List<bool> _consumed;

  ParseState(this.text) : _consumed = List.filled(text.normalized.length, false);

  /// Marcador que reemplaza los caracteres consumidos.
  static const consumedMark = '|';

  String get original => text.original;
  String get normalized => text.normalized;

  /// Texto normalizado con lo ya consumido sustituido por [consumedMark].
  String get available {
    final chars = text.normalized.split('');
    for (var i = 0; i < chars.length; i++) {
      if (_consumed[i]) chars[i] = consumedMark;
    }
    return chars.join();
  }

  bool isConsumed(int index) => _consumed[index];

  void consume(int start, int end) {
    for (var i = start; i < end && i < _consumed.length; i++) {
      _consumed[i] = true;
    }
  }

  void consumeMatch(Match match) => consume(match.start, match.end);

  /// Fragmento original (con mayúsculas/acentos) entre dos posiciones.
  String originalSlice(int start, int end) =>
      text.original.substring(start, end);

  /// Palabras que ningún parser reconoció.
  List<String> remainingWords() => RegExp(r'[a-z0-9@]+')
      .allMatches(available)
      .map((m) => m[0]!)
      .toList();
}
