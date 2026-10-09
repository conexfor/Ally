/// Expresiones de recurrencia (formas normalizadas, sin acentos).
library;

/// Diarias: "todos los días", "cada día", "a diario"...
const dailyPhrases = [
  'todos los dias',
  'todo los dias',
  'cada dia',
  'diariamente',
  'a diario',
];

/// "todas las mañanas", "todas las noches" → diaria + franja.
const dailyPeriodPrefix = ['todas las', 'cada'];

/// De lunes a viernes.
const weekdayPhrases = [
  'todos los dias laborables',
  'todos los dias habiles',
  'todos los dias de semana',
  'dias laborables',
  'dias habiles',
  'dias de semana',
  'entre semana',
];

/// Sábado y domingo.
const weekendPhrases = [
  'todos los fines de semana',
  'los fines de semana',
  'fines de semana',
  'cada fin de semana',
];

/// Prefijos que convierten días de la semana en recurrencia semanal:
/// "todos los lunes", "cada martes", "los jueves".
const weeklyListPrefixes = ['todos los', 'todas las', 'cada', 'los'];

/// Semanal sin días explícitos ("cada semana").
const weeklyPhrases = ['cada semana', 'todas las semanas', 'semanalmente'];

/// Mensual.
const monthlyPhrases = ['cada mes', 'todos los meses', 'mensualmente'];
