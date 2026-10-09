# Motor de lenguaje natural (sin IA)

El asistente de Ally entiende comandos en español mediante un **motor propio basado en reglas**: normalización de texto, expresiones regulares, diccionarios, extracción de entidades y un sistema de *intents*. No usa ninguna API de inteligencia artificial ni servicios externos: todo se ejecuta en el dispositivo (también sin conexión) y en el backend (`POST /api/parser/parse`) con el mismo código, que vive en `packages/ally_core/lib/src/nlp/`.

## Flujo

```text
Texto
 ↓  TextNormalizer            minúsculas, sin acentos, espacios, abreviaturas (misma longitud)
 ↓  MessageParser             "que diga …", texto entre comillas, "recuérdale que …"
 ↓  IntentDetector            CREATE_ALARM, DELETE_ALARM, LIST_ALARMS…
 ↓  RecurrenceParser          "todos los lunes", "de lunes a viernes", "cada 2 días"
 ↓  TimeParser                "8", "2:30 pm", "8 de la noche", "2 y media", "en 10 minutos"
 ↓  DateParser                "mañana", "el próximo lunes", "3 de octubre", "03/10/2026"
 ↓  RecipientParser / GroupParser   "para Juan y María", "@juan", "todo el equipo"
 ↓  = ParsedCommand           (análisis sintáctico, sin datos del usuario)
 ↓  DraftBuilder              resuelve fechas, AM/PM, personas, grupos y alarmas referenciadas
 ↓  DraftNormalizer           completa lo deducible (hoy/mañana, 1.ª ocurrencia)
 ↓  CommandValidator          valida y genera preguntas (Clarification)
 ↓  CommandConfirmation       resumen "Nueva alarma ⏰ 08:00 AM 📅 Mañana 👤 Nicolás"
 ↓  = InterpretationResult    estado + borrador + preguntas + confirmación
 ↓  (la app) CommandExecutor  ejecuta tras la confirmación del usuario
```

Cada parser **consume** el fragmento que reconoce (lo sustituye por `|` en `ParseState.available`). Así, por ejemplo, "8 **de la mañana**" se interpreta como franja horaria y ya no puede leerse como la fecha "mañana". Como la normalización conserva la longitud del texto, las posiciones sirven para recuperar el texto original con mayúsculas y acentos (mensajes y nombres).

## Componentes

| Componente | Archivo | Responsabilidad |
|---|---|---|
| `CommandInterpreter` | `command_interpreter.dart` | Interfaz (asíncrona) de cualquier intérprete. |
| `RuleBasedCommandInterpreter` | `rule_based_command_interpreter.dart` | Implementación actual: orquesta el flujo, aplica respuestas del usuario. |
| `NaturalLanguageAlarmParser` | `natural_language_alarm_parser.dart` | Análisis sintáctico completo. |
| `IntentDetector` | `parsers/intent_detector.dart` | Elige el intent con las reglas de `lexicon/intent_lexicon.dart`. |
| `TimeParser`, `DateParser`, `RecurrenceParser`, `MessageParser`, `RecipientParser`, `GroupParser`, `DurationParser` | `parsers/` | Extracción de entidades. |
| `ScheduleResolver` | `resolution/schedule_resolver.dart` | Fechas concretas y política AM/PM. |
| `RecipientResolver` | `resolution/recipient_resolver.dart` | Personas/grupos contra los contactos; nunca elige al azar. |
| `AlarmMatcher` | `resolution/alarm_matcher.dart` | "La alarma de las 3" → alarma concreta. |
| `CommandValidator` | `command_validator.dart` | Errores y preguntas (todas en lenguaje de usuario). |
| `CommandConfirmation` | `command_confirmation.dart` | Resumen previo a ejecutar. |
| `ConfirmationReplyParser` | `confirmation_reply_parser.dart` | "sí", "dale", "cancelar"… |

Los **diccionarios** están separados por responsabilidad en `lexicon/`:

```text
lexicon/
  abbreviation_lexicon.dart   q → que, mñn → mañana, pa → para…
  intent_lexicon.dart         reglas de intents
  number_lexicon.dart         números escritos ("ocho", "treinta y cinco")
  date_lexicon.dart           días, meses, "hoy/mañana/pasado mañana", modificadores
  time_lexicon.dart           franjas del día, AM/PM y tabla de uso habitual de horas
  recurrence_lexicon.dart     "todos los días", "entre semana", "fines de semana"…
  message_lexicon.dart        "que diga", "con el mensaje", comillas
  recipient_lexicon.dart      verbos con destinatario, "para mí", artículos
  filler_lexicon.dart         palabras sin contenido (para medir lo no entendido)
```

## Horas ambiguas (AM/PM)

El intérprete **no asume en silencio** cuando la ambigüedad importa. Reglas (`ScheduleResolver`):

1. AM/PM explícito, franja ("de la tarde") o formato 24 h (`08:00`, `14:30`) → sin dudas.
2. Fecha futura explícita ("mañana a las 8") → uso habitual según `habitualMeridiem` (7–11 → AM, 12–5 → PM, 6 → pregunta).
3. Hoy o sin fecha → si la lectura habitual aún no pasó, se usa; si el usuario dijo "hoy" y solo una lectura queda en el futuro, se usa esa.
4. En cualquier otro caso pregunta: *"¿Quieres programarla a las 8:00 PM (hoy) o a las 8:00 AM (mañana)?"*.

La tabla `habitualMeridiem` de `time_lexicon.dart` es configurable.

Para referencias a alarmas existentes ("cancela la alarma de las 5") se guardan **ambas** lecturas (17:00 y 05:00, la habitual primero) y `AlarmMatcher` busca entre las alarmas reales; si hay varias coincidencias, pregunta cuál.

## Aclaraciones y respuestas

Cuando falta información, el resultado tiene `status = needs_clarification` y una lista de `Clarification` (se pregunta de una en una). Cada `ClarificationOption` lleva un `patch` que modifica el borrador (`DraftPatcher`). El usuario puede:

- tocar una opción → `interpreter.applyOption(draft, option, ctx)`;
- escribir la respuesta ("pm", "Carlos Gómez", "el primero", "a las 7:30") → `interpreter.answer(pending, text, ctx)`;
- escribir un comando nuevo → se interpreta desde cero.

El `InterpretationResult` es serializable (`toJson`/`fromJson`), por eso el chat puede guardarlo en el historial y el backend puede recibir el estado pendiente.

## Cómo agregar una nueva expresión

La mayoría de cambios solo tocan diccionarios:

- **Nuevo verbo para crear alarmas** (p. ej. "márcame"): añádelo a la regla `CommandIntent.createAlarm` de `intent_lexicon.dart` y, si no debe contar como palabra no entendida, a `fillerVerbPattern` de `filler_lexicon.dart`.
- **Nueva abreviatura**: `abbreviation_lexicon.dart`.
- **Nueva forma de recurrencia** ("a diario de lunes a sábado"): `recurrence_lexicon.dart` o un nuevo `_parseX` en `RecurrenceParser`.
- **Nuevo marcador de mensaje** ("con la nota"): `message_lexicon.dart`.

Después, añade casos en `packages/ally_core/test/nlp/` y ejecuta `dart test`.

## Cómo agregar un nuevo intent

1. Añade el valor en `CommandIntent` (`model/command_intent.dart`) con su código estable (p. ej. `SHARE_ALARM`) y, si modifica datos, inclúyelo en `isMutation`.
2. Añade una `IntentRule` en `intent_lexicon.dart` con sus patrones y prioridad (más específico → mayor prioridad).
3. Si necesita entidades propias, crea un parser en `parsers/` y llámalo desde `NaturalLanguageAlarmParser.parse`.
4. Resuélvelo en `DraftBuilder.build` y valida en `CommandValidator.validate`.
5. Describe la confirmación en `CommandConfirmation.build`.
6. Ejecútalo en la app (`app/lib/application/assistant/command_executor.dart`).
7. Tests en `test/nlp/`.

## IA opcional en el futuro

Toda la app depende de la interfaz `CommandInterpreter`, no de la implementación. Una versión futura podría añadir un `AICommandInterpreter` que produzca el mismo `InterpretationResult` (y, por ejemplo, recurra al intérprete por reglas sin conexión). **Esa clase no existe en esta versión**: el sistema funciona íntegramente sin IA.

## Tests

`packages/ally_core/test/nlp/` contiene más de 180 casos: ejemplos de la especificación, formatos de hora y fecha, ambigüedad AM/PM, recurrencias, destinatarios múltiples, ambiguos e inexistentes, todos los intents, respuestas a aclaraciones, serialización y entradas extrañas (nunca lanza excepciones).

```bash
cd packages/ally_core && dart test
```
