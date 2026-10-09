/// Diccionarios de fechas (formas normalizadas, sin acentos).
library;

/// Día de la semana → número ISO (1 = lunes).
const weekdayWords = <String, int>{
  'lunes': 1,
  'martes': 2,
  'miercoles': 3,
  'jueves': 4,
  'viernes': 5,
  'sabado': 6,
  'sabados': 6,
  'domingo': 7,
  'domingos': 7,
};

/// Nombres para mostrar al usuario.
const weekdayDisplayNames = <int, String>{
  1: 'lunes',
  2: 'martes',
  3: 'miércoles',
  4: 'jueves',
  5: 'viernes',
  6: 'sábado',
  7: 'domingo',
};

const monthWords = <String, int>{
  'enero': 1,
  'febrero': 2,
  'marzo': 3,
  'abril': 4,
  'mayo': 5,
  'junio': 6,
  'julio': 7,
  'agosto': 8,
  'septiembre': 9,
  'setiembre': 9,
  'octubre': 10,
  'noviembre': 11,
  'diciembre': 12,
};

const monthDisplayNames = <int, String>{
  1: 'enero',
  2: 'febrero',
  3: 'marzo',
  4: 'abril',
  5: 'mayo',
  6: 'junio',
  7: 'julio',
  8: 'agosto',
  9: 'septiembre',
  10: 'octubre',
  11: 'noviembre',
  12: 'diciembre',
};

/// Expresiones de día relativo → desplazamiento en días desde hoy.
/// El orden importa: las más largas primero.
const relativeDayWords = <String, int>{
  'pasado manana': 2,
  'manana': 1,
  'hoy': 0,
};

/// Modificadores que indican "la próxima ocurrencia estrictamente futura".
const nextWeekdayModifiers = ['el proximo', 'proximo', 'el siguiente', 'este proximo'];

/// Modificadores que indican "esta semana" (hoy incluido).
const thisWeekdayModifiers = ['este', 'esta', 'el', 'la'];

/// Sufijos que indican "la próxima" ("el lunes que viene").
const nextWeekdaySuffixes = ['que viene', 'proximo', 'siguiente'];

String alternation(Iterable<String> words) {
  final sorted = words.toList()..sort((a, b) => b.length.compareTo(a.length));
  return sorted.map((w) => w.replaceAll(' ', r'\s+')).join('|');
}
