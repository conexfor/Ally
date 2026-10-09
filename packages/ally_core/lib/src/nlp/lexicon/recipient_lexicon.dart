/// Diccionarios para reconocer destinatarios (texto normalizado).
library;

/// Verbos que llevan el destinatario detrás: "recuérdale a Juan",
/// "despierta a María", "avísales a Juan y Pedro".
const recipientVerbs = [
  'recuerdale',
  'recuerdales',
  'recordarle',
  'recordarles',
  'avisale',
  'avisales',
  'avisa',
  'avisarle',
  'despierta',
  'despiertale',
  'despertar',
  'levanta',
  'levantale',
  'llama',
  'enviale',
  'envia',
  'mandale',
  'manda',
  'comparte',
];

/// Formas que indican que el destinatario es el propio usuario.
const selfPatterns = [
  r'\b(?:recuerdame|recordarme|despiertame|despertarme|avisame|avisarme|levantame|llamame|ponme|ponerme|programame|creame|agendame|anotame|activame|configurame)\b',
  r'\b(?:para|a)\s+mi(?:\s+mism[oa])?(?=\s*(?:$|[|,.;:!?]|y\s|e\s))',
  r'\bpara\s+(?:yo|nosotros|nosotras)\b',
];

/// Palabras que cortan un segmento de destinatarios.
const recipientStopWords = [
  'que',
  'porque',
  'cuando',
  'si',
  'sobre',
  'desde',
  'hasta',
  'diciendo',
  'para',
  'a las',
  'a la',
];

/// Artículos/determinantes que pueden preceder a un destinatario.
const recipientArticles = [
  'a',
  'al',
  'el',
  'la',
  'los',
  'las',
  'un',
  'una',
  'mi',
  'mis',
  'a mi',
  'a mis',
  'a los',
  'a las',
];

/// Prefijos que indican "todo el grupo/equipo".
const wholeGroupPrefixes = ['todo el', 'toda la', 'todos los', 'todas las', 'a todo el', 'a toda la'];

/// Palabras que designan un grupo genérico.
const groupNouns = ['grupo', 'equipo'];
