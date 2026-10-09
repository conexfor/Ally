/// Números escritos con palabras (ya normalizados: sin acentos).
const _units = <String, int>{
  'cero': 0,
  'un': 1,
  'una': 1,
  'uno': 1,
  'dos': 2,
  'tres': 3,
  'cuatro': 4,
  'cinco': 5,
  'seis': 6,
  'siete': 7,
  'ocho': 8,
  'nueve': 9,
};

const _teens = <String, int>{
  'diez': 10,
  'once': 11,
  'doce': 12,
  'trece': 13,
  'catorce': 14,
  'quince': 15,
  'dieciseis': 16,
  'diecisiete': 17,
  'dieciocho': 18,
  'diecinueve': 19,
  'veinte': 20,
  'veintiun': 21,
  'veintiuno': 21,
  'veintiuna': 21,
  'veintidos': 22,
  'veintitres': 23,
  'veinticuatro': 24,
  'veinticinco': 25,
  'veintiseis': 26,
  'veintisiete': 27,
  'veintiocho': 28,
  'veintinueve': 29,
};

const _tens = <String, int>{
  'treinta': 30,
  'cuarenta': 40,
  'cincuenta': 50,
};

/// Todas las palabras numéricas simples (0–29, decenas).
final Map<String, int> numberWords = {..._units, ..._teens, ..._tens};

/// Patrón (sin grupos de captura) para un número entre 0 y 59 escrito con
/// dígitos o palabras, incluidas formas compuestas ("treinta y cinco").
final String numberPattern = () {
  final simple = (numberWords.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))
      .join('|');
  final tens = _tens.keys.join('|');
  final units = _units.keys.where((k) => k != 'cero').join('|');
  return '(?:\\d{1,2}|(?:$tens)\\s+y\\s+(?:$units)|$simple)';
}();

/// Convierte un número escrito (dígitos o palabras) a entero.
int? parseNumber(String raw) {
  final text = raw.trim();
  final asInt = int.tryParse(text);
  if (asInt != null) return asInt;
  final compound = RegExp(r'^(\w+)\s+y\s+(\w+)$').firstMatch(text);
  if (compound != null) {
    final tens = _tens[compound[1]];
    final unit = _units[compound[2]];
    if (tens != null && unit != null) return tens + unit;
  }
  return numberWords[text];
}
