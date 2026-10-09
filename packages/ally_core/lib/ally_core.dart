/// Núcleo compartido de Ally (app y backend).
library;

// Dominio
export 'src/domain/enums.dart';
export 'src/domain/local_date_time.dart';
export 'src/domain/repeat_rule.dart';

// Planificación
export 'src/scheduling/recurrence_calculator.dart';
export 'src/scheduling/ring_planner.dart';

// Motor de lenguaje natural (basado en reglas, sin IA)
export 'src/nlp/command_confirmation.dart';
export 'src/nlp/command_interpreter.dart';
export 'src/nlp/command_validator.dart';
export 'src/nlp/confirmation_reply_parser.dart';
export 'src/nlp/lexicon/time_lexicon.dart' show DayPeriod;
export 'src/nlp/model/command_draft.dart';
export 'src/nlp/model/command_intent.dart';
export 'src/nlp/model/interpretation_context.dart';
export 'src/nlp/model/interpretation_result.dart';
export 'src/nlp/model/mentions.dart';
export 'src/nlp/model/parsed_command.dart';
export 'src/nlp/natural_language_alarm_parser.dart';
export 'src/nlp/resolution/draft_patcher.dart' show PatchKeys;
export 'src/nlp/rule_based_command_interpreter.dart';
export 'src/nlp/spanish_formatter.dart';
export 'src/nlp/text_normalizer.dart' show TextNormalizer;

// Zonas horarias
export 'src/scheduling/zoned_schedule.dart';

// Validación compartida
export 'src/validation/validators.dart';

// Contratos de la API
export 'src/api/alarm_dtos.dart';
export 'src/api/contact_dtos.dart';
export 'src/api/group_dtos.dart';
export 'src/api/json.dart';
export 'src/api/misc_dtos.dart';
export 'src/api/sequence_dtos.dart';
export 'src/api/user_dtos.dart';
