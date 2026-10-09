import '../model/command_intent.dart';
import 'number_lexicon.dart';

/// Regla que asocia patrones (sobre texto normalizado) con un intent.
///
/// Cuando varias reglas coinciden gana la que aparece antes en la frase; si
/// empiezan en la misma posición, la de mayor [priority]. Así "Elimina a Juan
/// del grupo" es REMOVE_MEMBER (más específico) y no DELETE_ALARM.
class IntentRule {
  final CommandIntent intent;
  final List<String> patterns;
  final int priority;

  const IntentRule(this.intent, this.patterns, {required this.priority});
}

const _listVerbs =
    r'(?:muestr\w*|ensen\w*|lista\w*|ver|veo|mira\w*|consult\w*|dime|revis\w*|cuales\s+son|quienes\s+son)';
const _anyWords = r'(?:\s+[a-z]+){0,3}?';

final List<IntentRule> intentRules = [
  // --- Grupos (los más específicos) ---
  const IntentRule(CommandIntent.createGroup, [
    r'\b(?:crea\w*|haz|hazme|arma|armar|forma|formar|agrega|anade|nuevo|nueva)\s+(?:un\s+|el\s+|otro\s+)?(?:nuevo\s+)?grupo\b',
  ], priority: 95),
  const IntentRule(CommandIntent.addMember, [
    r'\b(?:agreg|anad|mete|met|incluy|incorpor|sum|invit)\w*\b.*?\b(?:al|a\s+mi|a\s+el|en\s+el|en\s+mi)\s+(?:grupo|equipo)\b',
  ], priority: 95),
  const IntentRule(CommandIntent.removeMember, [
    r'\b(?:sac|quit|elimin|borr|expuls|remuev|remov|retir)\w*\b.*?\b(?:del|de\s+mi|de\s+el)\s+(?:grupo|equipo)\b',
  ], priority: 95),

  // --- Operaciones sobre alarmas existentes ---
  IntentRule(CommandIntent.snoozeAlarm, [
    r'\b(?:pospon\w*|pospong\w*|aplaz\w*|snooze)\b',
    r'\bdormir\s+(?:un\s+poco\s+)?mas\b',
    '\\b$numberPattern\\s+minutos\\s+mas\\b',
    '\\bdame\\s+(?:otros\\s+)?$numberPattern\\s+minutos\\b',
  ], priority: 80),
  const IntentRule(CommandIntent.editAlarm, [
    r'\b(?:cambi|modific|edit|reprogram|actualiz|corrig|ajust)\w*\b',
    r'\b(?:mueve|muevela|mover|moverla|pasa|pasala|pasar|adelanta|adelantala|atrasa|atrasala|retrasa|retrasala)\b(?=.*\b(?:alarma|de\s+las?|a\s+las?|al)\b)',
  ], priority: 75),
  const IntentRule(CommandIntent.cancelAlarm, [
    r'\b(?:desactiv|apag|deten|silenci|omit)\w*\b',
    r'^(?:para|parar|detener)\s+(?:la\s+)?alarma\b',
    r'\bque\s+no\s+suene\b',
  ], priority: 72),
  const IntentRule(CommandIntent.deleteAlarm, [
    r'\b(?:cancel|elimin|borr|anul|suprim)\w*\b',
    r'\bquita\w*\b(?=.*\balarma)',
    r'\bya\s+no\s+(?:quiero|necesito)\s+(?:la\s+)?alarma\b',
  ], priority: 70),

  // --- Consultas ---
  const IntentRule(CommandIntent.listAlarms, [
    r'\b(?:que|cuales|cuantas)\s+alarmas?\b',
    '\\b$_listVerbs$_anyWords\\s+alarmas?\\b',
    r'\bmis\s+alarmas\b',
    r'\balarmas\s+(?:tengo|hay|pendientes|programadas|activas)\b',
    r'\b(?:tengo|hay)\s+(?:alguna\s+|algunas\s+)?alarmas?\b',
  ], priority: 60),
  const IntentRule(CommandIntent.listContacts, [
    r'\b(?:mis|los)\s+contactos\b',
    '\\b$_listVerbs$_anyWords\\s+contactos\\b',
    r'\bcon\s+quien(?:es)?\s+estoy\s+conectad[oa]s?\b',
  ], priority: 60),
  const IntentRule(CommandIntent.listGroups, [
    r'\b(?:mis|los)\s+grupos\b',
    r'\b(?:que|cuales|cuantos)\s+grupos\b',
    '\\b$_listVerbs$_anyWords\\s+grupos\\b',
  ], priority: 60),

  // --- Crear alarma ---
  const IntentRule(CommandIntent.createAlarm, [
    r'\b(?:crea|crear|creame|creale|creales|cree|crees|creas|creen)\b',
    r'\b(?:pon|poner|ponme|ponle|ponles|ponnos|pongas|ponga|pongan|ponerme|ponerle)\b',
    r'\b(?:programa|programar|programame|programale|programales|programes|programe)\b',
    r'\b(?:establece|establecer|configura|configurar|configurame|agenda|agendar|agendame|agendale|anota|anotame|activa|activar|activame|fija|fijar|define|definir)\b',
    r'\b(?:recuerd|record|despiert|despertar|avis|levant)\w*\b',
    r'\bhaz\w*\s+sonar\b',
    r'\b(?:nueva|nuevo)\s+(?:alarma|recordatorio|aviso)\b',
    r'^(?:una\s+)?(?:alarma|recordatorio|aviso)\b',
    r'\balarma\s+para\b',
    r'\b(?:quiero|necesito)\s+(?:una\s+)?alarma\b',
  ], priority: 50),

  // --- Ayuda ---
  const IntentRule(CommandIntent.help, [
    r'\b(?:ayuda|ayudame|help|comandos|instrucciones)\b',
    r'\bque\s+(?:puedes|sabes)\s+hacer\b',
    r'\bcomo\s+(?:funciona\w*|te\s+uso|se\s+usa)\b',
    r'^(?:hola|buenas|buenos\s+dias|buenas\s+tardes|buenas\s+noches|hey|hi)\W*$',
  ], priority: 40),
];
