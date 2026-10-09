/// Diccionarios de horas (formas normalizadas, sin acentos).
library;

/// Franja del día mencionada por el usuario.
enum DayPeriod {
  morning('morning'),
  afternoon('afternoon'),
  night('night'),
  earlyMorning('early_morning'),
  noon('noon');

  const DayPeriod(this.wire);
  final String wire;

  static DayPeriod fromWire(String w) =>
      values.firstWhere((p) => p.wire == w, orElse: () => DayPeriod.morning);
}

const dayPeriodWords = <String, DayPeriod>{
  'manana': DayPeriod.morning,
  'mananas': DayPeriod.morning,
  'tarde': DayPeriod.afternoon,
  'tardes': DayPeriod.afternoon,
  'noche': DayPeriod.night,
  'noches': DayPeriod.night,
  'madrugada': DayPeriod.earlyMorning,
  'mediodia': DayPeriod.noon,
};

/// Fracciones de hora: "y media", "y cuarto", "menos cuarto".
const fractionWords = <String, int>{
  'media': 30,
  'cuarto': 15,
};

/// Indicadores AM/PM: `am`, `a.m.`, `a. m.`, `pm`, `p.m.`...
const meridiemPattern = r'(a\.?\s?m\.?|p\.?\s?m\.?)(?![a-z])';

/// Franja tras una hora: "de la mañana", "por la tarde", "del mediodía".
const periodAfterHourPattern =
    r'(?:(?:de|en|por)\s+la\s+(manana|tarde|noche|madrugada)|del?\s+(?:el\s+)?(mediodia))';

/// Sufijos de hora que se ignoran: "en punto", "hrs", "h".
const hourSuffixPattern = r'(?:\s+en\s+punto)?(?:\s*(?:horas|hora|hs|h)(?![a-z]))?';

/// Interpretación habitual de una hora de 1 a 12 sin indicar AM/PM.
///
/// - `am`/`pm`: el uso habitual es suficientemente claro como para inferirlo.
/// - `null`: ambigüedad real; el asistente pregunta al usuario.
///
/// Configurable: modificar esta tabla cambia el comportamiento sin tocar el
/// parser.
const habitualMeridiem = <int, String?>{
  1: 'pm',
  2: 'pm',
  3: 'pm',
  4: 'pm',
  5: 'pm',
  6: null,
  7: 'am',
  8: 'am',
  9: 'am',
  10: 'am',
  11: 'am',
  12: 'pm',
};
