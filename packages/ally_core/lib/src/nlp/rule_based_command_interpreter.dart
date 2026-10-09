import 'command_confirmation.dart';
import 'command_interpreter.dart';
import 'command_validator.dart';
import 'model/command_draft.dart';
import 'model/command_intent.dart';
import 'model/interpretation_context.dart';
import 'model/interpretation_result.dart';
import 'natural_language_alarm_parser.dart';
import 'parse_state.dart';
import 'parsers/duration_parser.dart';
import 'resolution/draft_builder.dart';
import 'resolution/draft_normalizer.dart';
import 'resolution/draft_patcher.dart';
import 'resolution/recipient_resolver.dart';
import 'resolution/schedule_resolver.dart';
import 'text_normalizer.dart';

/// Intérprete de comandos basado exclusivamente en reglas.
///
/// Flujo: texto → [NaturalLanguageAlarmParser] (normalización, intent,
/// entidades) → [DraftBuilder] (resolución de fechas, horas, personas y
/// alarmas) → [DraftNormalizer] → [CommandValidator] → [CommandConfirmation].
class RuleBasedCommandInterpreter implements CommandInterpreter {
  final NaturalLanguageAlarmParser _parser;
  final DraftBuilder _builder;
  final DraftNormalizer _normalizer;
  final DraftPatcher _patcher;
  final CommandValidator _validator;
  final CommandConfirmation _confirmation;
  final ScheduleResolver _schedule;

  RuleBasedCommandInterpreter({
    NaturalLanguageAlarmParser? parser,
    DraftBuilder builder = const DraftBuilder(),
    DraftNormalizer normalizer = const DraftNormalizer(),
    DraftPatcher patcher = const DraftPatcher(),
    CommandValidator validator = const CommandValidator(),
    CommandConfirmation confirmation = const CommandConfirmation(),
    ScheduleResolver schedule = const ScheduleResolver(),
  })  : _parser = parser ?? NaturalLanguageAlarmParser(),
        _builder = builder,
        _normalizer = normalizer,
        _patcher = patcher,
        _validator = validator,
        _confirmation = confirmation,
        _schedule = schedule;

  static const helpText =
      'Puedo crear y gestionar alarmas por ti. Prueba, por ejemplo:\n'
      '• "Crea una alarma mañana a las 8 para Juan"\n'
      '• "Todos los lunes a las 9 para el equipo"\n'
      '• "Recuérdame a las 5 de la tarde que diga \'Llamar a mamá\'"\n'
      '• "¿Qué alarmas tengo mañana?"\n'
      '• "Cancela la alarma de las 3"\n'
      '• "Posponer 10 minutos"\n'
      '• "Crea un grupo llamado Familia con Juan y María"';

  static const notUnderstoodText =
      'No entendí la instrucción. Puedes decirme, por ejemplo: '
      '"Crea una alarma mañana a las 8 para Juan". '
      'Escribe "ayuda" para ver más ejemplos.';

  /// Versión síncrona de [interpret] (útil en tests y en el backend).
  InterpretationResult interpretSync(String text, InterpretationContext context) {
    if (text.trim().isEmpty) {
      return InterpretationResult(
        draft: CommandDraft(intent: CommandIntent.unknown, originalText: text),
        status: InterpretationStatus.notUnderstood,
        reply: notUnderstoodText,
      );
    }
    final parsed = _parser.parse(text);
    final draft = _builder.build(parsed, context);
    return evaluateSync(draft, context);
  }

  InterpretationResult evaluateSync(CommandDraft draft, InterpretationContext context) {
    var current = _normalizer.normalize(draft, context);
    current = _promoteResolvedRecipients(current, context);
    final outcome = _validator.validate(current, context);

    if (current.intent == CommandIntent.unknown) {
      return InterpretationResult(
        draft: current,
        status: InterpretationStatus.notUnderstood,
        reply: notUnderstoodText,
      );
    }
    if (current.intent == CommandIntent.help) {
      return InterpretationResult(
        draft: current,
        status: InterpretationStatus.readyToExecute,
        reply: helpText,
      );
    }
    if (outcome.hasErrors) {
      return InterpretationResult(
        draft: current,
        status: InterpretationStatus.invalid,
        issues: outcome.issues,
        reply: outcome.issues
            .firstWhere((i) => i.severity == IssueSeverity.error)
            .message,
      );
    }
    if (outcome.clarifications.isNotEmpty) {
      return InterpretationResult(
        draft: current,
        status: InterpretationStatus.needsClarification,
        clarifications: outcome.clarifications,
        issues: outcome.issues,
        reply: outcome.clarifications.first.question,
      );
    }
    if (!current.intent.isMutation) {
      return InterpretationResult(
        draft: current,
        status: InterpretationStatus.readyToExecute,
        issues: outcome.issues,
        reply: '',
      );
    }
    final summary = _confirmation.build(current, context)!;
    return InterpretationResult(
      draft: current,
      status: InterpretationStatus.needsConfirmation,
      issues: outcome.issues,
      confirmation: summary,
      reply: summary.toPlainText(),
    );
  }

  InterpretationResult applyOptionSync(
    CommandDraft draft,
    ClarificationOption option,
    InterpretationContext context,
  ) =>
      evaluateSync(_patcher.apply(draft, option.patch), context);

  InterpretationResult answerSync(
    InterpretationResult pending,
    String text,
    InterpretationContext context,
  ) {
    final clarification = pending.pendingClarification;
    if (clarification == null) return interpretSync(text, context);

    // ¿Eligió una de las opciones escribiendo su nombre o "la primera"?
    final option = _matchOption(clarification.options, text);
    if (option != null && option.action == OptionAction.none) {
      return applyOptionSync(pending.draft, option, context);
    }

    // ¿Es un comando completamente nuevo?
    final parsed = _parser.parse(text);
    if (parsed.intentExplicit && parsed.intent != CommandIntent.unknown) {
      return interpretSync(text, context);
    }

    final draft = pending.draft;
    switch (clarification.kind) {
      case ClarificationKind.meridiem:
        final choice = _meridiemChoice(clarification.options, text);
        if (choice != null) return applyOptionSync(draft, choice, context);
        return _answerTime(draft, text, context);
      case ClarificationKind.missingTime || ClarificationKind.pastDateTime:
        return _answerTime(draft, text, context);
      case ClarificationKind.recipientAmbiguous ||
            ClarificationKind.recipientNotFound ||
            ClarificationKind.groupNotFound ||
            ClarificationKind.groupAmbiguous:
        if (clarification.subject == null) break;
        if (draft.intent == CommandIntent.createAlarm) {
          final replaced = [
            for (final r in draft.unresolvedRecipients)
              r == clarification.subject ? text.trim() : r,
          ];
          return evaluateSync(draft.copyWith(unresolvedRecipients: replaced), context);
        }
        return evaluateSync(draft.copyWith(groupName: text.trim()), context);
      case ClarificationKind.memberAmbiguous || ClarificationKind.memberNotFound:
        final replaced = [
          for (final r in draft.unresolvedMembers)
            r == clarification.subject ? text.trim() : r,
        ];
        return evaluateSync(_resolveMembers(draft.copyWith(unresolvedMembers: replaced), context), context);
      case ClarificationKind.missingMembers:
        final names = text
            .split(RegExp(r'\s*,\s*|\s+(?:y|e)\s+'))
            .map((n) => n.trim().replaceFirst(RegExp(r'^a\s+', caseSensitive: false), ''))
            .where((n) => n.isNotEmpty)
            .toList();
        return evaluateSync(
          _resolveMembers(draft.copyWith(unresolvedMembers: names), context),
          context,
        );
      case ClarificationKind.missingGroupName:
        final name = text.trim().replaceAll(RegExp(r'^["“«]|["”»]$'), '');
        return evaluateSync(draft.copyWith(groupName: name), context);
      case ClarificationKind.snoozeDuration:
        final normalized = const TextNormalizer().normalize(text);
        final minutes = DurationParser().parse(ParseState(normalized)) ??
            int.tryParse(normalized.normalized.trim());
        if (minutes != null) {
          return evaluateSync(draft.copyWith(snoozeMinutes: minutes), context);
        }
      case ClarificationKind.alarmAmbiguous || ClarificationKind.alarmNotFound:
        break;
    }
    // No se pudo usar la respuesta: se repite la pregunta.
    return InterpretationResult(
      draft: draft,
      status: InterpretationStatus.needsClarification,
      clarifications: pending.clarifications,
      issues: pending.issues,
      reply: 'No te entendí. ${clarification.question}',
    );
  }

  InterpretationResult _answerTime(
    CommandDraft draft,
    String text,
    InterpretationContext context,
  ) {
    final parsed = _parser.parse(text);
    final schedule = _schedule.resolveForCreate(parsed, context);
    if (schedule.time == null && schedule.timeOptions.isEmpty) {
      return evaluateSync(draft, context).withReplyPrefix('No reconocí la hora. ');
    }
    final keepDate = parsed.dates.isEmpty && draft.repeat == null && !draft.dateInferred;
    return evaluateSync(
      draft.copyWith(
        time: schedule.time,
        timeOptions: schedule.timeOptions,
        date: parsed.dates.isNotEmpty
            ? schedule.date
            : (keepDate ? draft.date : schedule.date),
        dateInferred: parsed.dates.isEmpty && !keepDate,
      ),
      context,
    );
  }

  ClarificationOption? _meridiemChoice(List<ClarificationOption> options, String text) {
    final key = TextNormalizer.foldWithSameLength(text);
    final wantsAm = RegExp(r'\b(?:a\.?\s?m\.?|manana|madrugada)\b').hasMatch(key);
    final wantsPm = RegExp(r'\b(?:p\.?\s?m\.?|tarde|noche)\b').hasMatch(key);
    if (wantsAm == wantsPm) return null;
    for (final option in options) {
      final time = option.patch[PatchKeys.time] as String?;
      if (time == null) continue;
      final hour = int.parse(time.split(':').first);
      if ((hour < 12) == wantsAm) return option;
    }
    return null;
  }

  static ClarificationOption? _matchOption(List<ClarificationOption> options, String text) {
    if (options.isEmpty) return null;
    final key = TextNormalizer.nameKey(text);
    if (key.isEmpty) return null;
    const ordinals = {
      'primero': 0, 'primera': 0, 'el primero': 0, 'la primera': 0, '1': 0,
      'segundo': 1, 'segunda': 1, 'el segundo': 1, 'la segunda': 1, '2': 1,
      'tercero': 2, 'tercera': 2, 'el tercero': 2, 'la tercera': 2, '3': 2,
    };
    final index = ordinals[key];
    if (index != null && index < options.length) return options[index];
    for (final option in options) {
      if (TextNormalizer.nameKey(option.label) == key) return option;
    }
    final partial = options
        .where((o) => key.length >= 3 && TextNormalizer.nameKey(o.label).contains(key))
        .toList();
    return partial.length == 1 ? partial.single : null;
  }

  /// Mueve a la lista de destinatarios los pendientes que ahora se resuelven
  /// sin ambigüedad (p. ej. tras escribir un nombre más completo).
  CommandDraft _promoteResolvedRecipients(CommandDraft draft, InterpretationContext ctx) {
    if (draft.unresolvedRecipients.isEmpty) return draft;
    final recipients = [...draft.recipients];
    final pending = <String>[];
    for (final raw in draft.unresolvedRecipients) {
      final match = _validator.resolvePending(raw, ctx);
      if (match is RecipientResolved) {
        if (!recipients.any((r) => r.sameAs(match.recipient))) {
          recipients.add(match.recipient);
        }
      } else {
        pending.add(raw);
      }
    }
    return draft.copyWith(recipients: recipients, unresolvedRecipients: pending);
  }

  CommandDraft _resolveMembers(CommandDraft draft, InterpretationContext ctx) {
    const resolver = RecipientResolver();
    final members = [...draft.members];
    final pending = <String>[];
    for (final raw in draft.unresolvedMembers) {
      final match = raw.startsWith('@')
          ? resolver.resolveUsername(raw, ctx)
          : resolver.resolvePerson(raw, ctx);
      if (match is RecipientResolved) {
        if (!members.any((m) => m.sameAs(match.recipient))) members.add(match.recipient);
      } else {
        pending.add(raw);
      }
    }
    return draft.copyWith(members: members, unresolvedMembers: pending);
  }

  // --- Interfaz asíncrona ---

  @override
  Future<InterpretationResult> interpret(String text, InterpretationContext context) async =>
      interpretSync(text, context);

  @override
  Future<InterpretationResult> applyOption(
    CommandDraft draft,
    ClarificationOption option,
    InterpretationContext context,
  ) async =>
      applyOptionSync(draft, option, context);

  @override
  Future<InterpretationResult> answer(
    InterpretationResult pending,
    String text,
    InterpretationContext context,
  ) async =>
      answerSync(pending, text, context);

  @override
  Future<InterpretationResult> evaluate(
    CommandDraft draft,
    InterpretationContext context,
  ) async =>
      evaluateSync(draft, context);
}

extension on InterpretationResult {
  InterpretationResult withReplyPrefix(String prefix) => InterpretationResult(
        draft: draft,
        status: status,
        clarifications: clarifications,
        issues: issues,
        confirmation: confirmation,
        reply: '$prefix$reply',
      );
}
