/// Marcadores que introducen el mensaje de una alarma (texto normalizado).
library;

/// Pares de comillas aceptados para delimitar un mensaje exacto.
const quotePairs = <String, String>{
  '"': '"',
  '“': '”',
  '«': '»',
  "'": "'",
};

/// Expresiones tras las cuales todo el resto de la frase es el mensaje:
/// `que diga reunión de proyecto`, `con el mensaje: llamar a mamá`...
const messageMarkers = [
  r'que\s+(?:diga|digan|dice|ponga|muestre)',
  r'con\s+(?:el\s+|la\s+)?(?:mensaje|texto|titulo|nombre|nota|asunto|motivo|descripcion)(?:\s+de)?',
  r'(?:mensaje|titulo|nota|asunto|motivo)\s*:',
  r'diciendo',
  r'(?:titulada|titulado|llamada)',
  r'que\s+se\s+llame',
];

/// Verbos de recordatorio cuyo complemento "que ..." es el mensaje:
/// "Recuérdale a Juan que llame al médico".
const reminderVerbsPattern = r'\b(?:recuerd\w*|record\w*|avis\w*|di\w*le)\b';

/// Longitud máxima del mensaje de una alarma.
const maxMessageLength = 200;
