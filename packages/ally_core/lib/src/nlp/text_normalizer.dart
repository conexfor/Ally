import 'lexicon/abbreviation_lexicon.dart';

/// Resultado de normalizar un texto.
///
/// [normalized] tiene exactamente la misma longitud que [original], de modo
/// que cualquier posición encontrada en el texto normalizado sirve para
/// recuperar el fragmento original (con mayúsculas y acentos) del usuario.
class NormalizedText {
  /// Texto del usuario con espacios colapsados y abreviaturas expandidas.
  final String original;

  /// Minúsculas, sin acentos (`ñ` → `n`), misma longitud que [original].
  final String normalized;

  const NormalizedText(this.original, this.normalized);
}

/// Normaliza mayúsculas, espacios, acentos y abreviaturas comunes.
class TextNormalizer {
  const TextNormalizer();

  static const _accentMap = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
    // `|` se reserva como marcador de texto ya consumido por los parsers.
    '|': ' ',
  };

  NormalizedText normalize(String input) {
    var text = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = _expandAbbreviations(text);
    return NormalizedText(text, foldWithSameLength(text));
  }

  /// Minúsculas y sin acentos, carácter a carácter (preserva la longitud).
  static String foldWithSameLength(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      var lower = char.toLowerCase();
      if (lower.length != char.length) lower = char;
      buffer.write(_accentMap[lower] ?? lower);
    }
    return buffer.toString();
  }

  /// Clave de comparación para nombres: minúsculas, sin acentos, sin `@`
  /// ni signos, espacios simples.
  static String nameKey(String text) => foldWithSameLength(text)
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _expandAbbreviations(String text) {
    return text.replaceAllMapped(_abbreviationPattern, (m) {
      final word = m[0]!;
      return _foldedAbbreviations[foldWithSameLength(word)] ?? word;
    });
  }

  static final _foldedAbbreviations = {
    for (final e in abbreviations.entries) foldWithSameLength(e.key): e.value,
  };

  static final _abbreviationPattern = RegExp(
    '(?<![\\p{L}\\d])(${abbreviations.keys.map(RegExp.escape).join('|')})(?![\\p{L}\\d])',
    caseSensitive: false,
    unicode: true,
  );
}
