/// Palabras que no aportan información propia (artículos, cortesía, verbos de
/// orden...). Se ignoran al medir cuánto de la frase quedó sin entender.
const fillerWords = <String>{
  // artículos, preposiciones, conjunciones
  'a', 'al', 'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de',
  'del', 'en', 'por', 'para', 'con', 'y', 'e', 'o', 'u', 'que', 'se', 'lo',
  'le', 'les', 'me', 'te', 'nos', 'mi', 'mis', 'tu', 'su', 'sus', 'esta',
  'este', 'eso', 'esa', 'ese', 'ya', 'tambien', 'solo', 'otra', 'otro',
  'nueva', 'nuevo', 'hora', 'horas', 'dia', 'dias', 'todo', 'todos', 'toda',
  'todas',
  // sustantivos del dominio
  'alarma', 'alarmas', 'recordatorio', 'recordatorios', 'aviso', 'avisos',
  'grupo', 'grupos', 'contacto', 'contactos', 'mensaje', 'equipo',
  // cortesía y relleno
  'por favor', 'favor', 'gracias', 'porfavor', 'puedes', 'podrias', 'quiero',
  'necesito', 'quisiera', 'me gustaria', 'gustaria', 'hola', 'oye', 'bueno',
  'pues', 'ahora', 'tengo', 'hay', 'cual', 'cuales', 'cuantas', 'cuantos',
  'como', 'mas', 'no', 'si', 'mismo', 'misma', 'minutos', 'minuto',
};

/// Raíces verbales de órdenes conocidas (crear, poner, cancelar...).
final fillerVerbPattern = RegExp(
  r'^(?:cre|pon|pong|program|establec|configur|agend|anot|activ|fij|defin|'
  r'recuerd|record|despiert|despert|avis|levant|haz|cancel|elimin|borr|anul|'
  r'suprim|quit|desactiv|apag|deten|silenci|omit|pospon|pospong|aplaz|cambi|'
  r'modific|edit|reprogram|actualiz|corrig|ajust|muev|mov|pas|adelant|atras|'
  r'retras|muestr|ensen|list|ver|veo|mir|consult|dime|revis|agreg|anad|met|'
  r'incluy|incorpor|sum|invit|sac|expuls|remuev|remov|retir|arm|form|dame|'
  r'dorm|sone|suen|diga|dice)\w*$',
);

bool isFillerWord(String word) =>
    fillerWords.contains(word) || fillerVerbPattern.hasMatch(word);
