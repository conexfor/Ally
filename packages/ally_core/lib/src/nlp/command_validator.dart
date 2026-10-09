import '../domain/local_date_time.dart';
import 'model/command_draft.dart';
import 'model/command_intent.dart';
import 'model/interpretation_context.dart';
import 'model/interpretation_result.dart';
import 'model/mentions.dart';
import 'resolution/alarm_matcher.dart';
import 'resolution/draft_patcher.dart';
import 'resolution/recipient_resolver.dart';
import 'spanish_formatter.dart';
import 'text_normalizer.dart';

class ValidationOutcome {
  final List<ValidationIssue> issues;
  final List<Clarification> clarifications;
  const ValidationOutcome(this.issues, this.clarifications);

  bool get hasErrors => issues.any((i) => i.severity == IssueSeverity.error);
}

/// Comprueba que un borrador tenga todo lo necesario y genera las preguntas
/// para lo que falte. Todos los mensajes están pensados para el usuario final.
class CommandValidator {
  final RecipientResolver _recipients;
  final AlarmMatcher _alarms;

  const CommandValidator({
    RecipientResolver recipients = const RecipientResolver(),
    AlarmMatcher alarms = const AlarmMatcher(),
  })  : _recipients = recipients,
        _alarms = alarms;

  static const maxSnoozeMinutes = 24 * 60;
  static const maxGroupNameLength = 60;
  static const maxYearsAhead = 2;

  ValidationOutcome validate(CommandDraft draft, InterpretationContext ctx) {
    final issues = <ValidationIssue>[];
    final questions = <Clarification>[];

    if (draft.invalidDate) {
      issues.add(const ValidationIssue('invalid_date', 'La fecha indicada no existe.'));
    }

    switch (draft.intent) {
      case CommandIntent.createAlarm:
        _validateSchedule(draft, ctx, issues, questions);
        _validateRecipients(draft, ctx, questions);
      case CommandIntent.editAlarm:
        _validateTarget(draft, ctx, issues, questions);
        _validateEditChanges(draft, ctx, issues, questions);
      case CommandIntent.deleteAlarm || CommandIntent.cancelAlarm:
        _validateTarget(draft, ctx, issues, questions);
      case CommandIntent.snoozeAlarm:
        _validateTarget(draft, ctx, issues, questions);
        _validateSnooze(draft, issues, questions);
      case CommandIntent.createGroup:
        _validateGroupName(draft, issues, questions);
        _validateMembers(draft, ctx, questions, required: false);
      case CommandIntent.addMember || CommandIntent.removeMember:
        _validateGroupReference(draft, ctx, questions);
        _validateMembers(draft, ctx, questions, required: true);
      default:
        break;
    }
    return ValidationOutcome(issues, questions);
  }

  // ---------------------------------------------------------------- horario

  void _validateSchedule(
    CommandDraft draft,
    InterpretationContext ctx,
    List<ValidationIssue> issues,
    List<Clarification> questions,
  ) {
    if (draft.timeOptions.isNotEmpty) {
      questions.add(_meridiemQuestion(draft.timeOptions, ctx, recurring: draft.repeat != null));
      return;
    }
    if (draft.time == null) {
      questions.add(const Clarification(
        kind: ClarificationKind.missingTime,
        question: '¿A qué hora quieres la alarma?',
        allowsFreeText: true,
      ));
      return;
    }
    final at = draft.scheduledAt;
    if (at == null) return;
    if (draft.repeat == null && !at.isAfter(ctx.nowLocal)) {
      final tomorrow = ctx.today.addDays(1);
      issues.add(const ValidationIssue(
        'past_date_time',
        'Esa fecha y hora ya pasaron.',
        severity: IssueSeverity.warning,
      ));
      questions.add(Clarification(
        kind: ClarificationKind.pastDateTime,
        question: 'Esa hora ya pasó. ¿Quieres programarla para mañana a las '
            '${SpanishFormatter.shortTime(draft.time!)}?',
        allowsFreeText: true,
        options: [
          ClarificationOption(
            id: 'tomorrow',
            label: 'Mañana a las ${SpanishFormatter.shortTime(draft.time!)}',
            patch: {
              PatchKeys.date: tomorrow.toString(),
              PatchKeys.time: draft.time.toString(),
            },
          ),
          const ClarificationOption(
            id: 'cancel',
            label: 'Cancelar',
            action: OptionAction.cancel,
          ),
        ],
      ));
      return;
    }
    if (at.date.isAfter(ctx.today.addDays(366 * maxYearsAhead))) {
      issues.add(const ValidationIssue(
        'date_too_far',
        'Solo puedo programar alarmas con hasta 2 años de antelación.',
      ));
    }
  }

  Clarification _meridiemQuestion(
    List<LocalDateTime> options,
    InterpretationContext ctx, {
    required bool recurring,
  }) {
    final differentDates = options.map((o) => o.date).toSet().length > 1;
    String label(LocalDateTime o) {
      final time = SpanishFormatter.shortTime(o.time);
      return differentDates
          ? '$time (${SpanishFormatter.date(o.date, ctx.today).toLowerCase()})'
          : time;
    }

    final labels = options.map(label).toList();
    return Clarification(
      kind: ClarificationKind.meridiem,
      question: '¿Quieres programarla a las ${labels.join(' o a las ')}?',
      allowsFreeText: true,
      options: [
        for (final (i, o) in options.indexed)
          ClarificationOption(
            id: 'option_$i',
            label: labels[i],
            patch: {
              PatchKeys.time: o.time.toString(),
              if (!recurring) PatchKeys.date: o.date.toString(),
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------- destinatarios

  void _validateRecipients(
    CommandDraft draft,
    InterpretationContext ctx,
    List<Clarification> questions,
  ) {
    if (draft.unresolvedRecipients.isEmpty) return;
    final raw = draft.unresolvedRecipients.first;
    final match = _resolveRaw(raw, ctx);
    final display = _displayRaw(raw);

    switch (match) {
      case RecipientAmbiguous(:final candidates):
        final isGroup = candidates.first.type == ResolvedRecipientType.group;
        questions.add(Clarification(
          kind: isGroup
              ? ClarificationKind.groupAmbiguous
              : ClarificationKind.recipientAmbiguous,
          subject: raw,
          question: isGroup
              ? 'Encontré varios grupos que coinciden con "$display". ¿A cuál deseas enviar la alarma?'
              : 'Encontré varios usuarios llamados $display. ¿A cuál deseas enviar la alarma?',
          options: [
            for (final c in candidates)
              ClarificationOption(
                id: c.id ?? c.displayName,
                label: c.displayName,
                patch: {
                  PatchKeys.addRecipient: c.toJson(),
                  PatchKeys.resolveRecipient: raw,
                },
              ),
          ],
        ));
      case RecipientNotFound() when _isGroupRaw(raw):
        questions.add(Clarification(
          kind: ClarificationKind.groupNotFound,
          subject: raw,
          question: ctx.groups.isEmpty
              ? 'No encontré el grupo "$display". Todavía no perteneces a ningún grupo.'
              : 'No encontré el grupo "$display". ¿Te refieres a alguno de estos?',
          options: [
            for (final g in ctx.groups.take(8))
              ClarificationOption(
                id: g.groupId,
                label: g.name,
                patch: {
                  PatchKeys.addRecipient: ResolvedRecipient(
                    type: ResolvedRecipientType.group,
                    id: g.groupId,
                    displayName: g.name,
                  ).toJson(),
                  PatchKeys.resolveRecipient: raw,
                },
              ),
            const ClarificationOption(
              id: 'cancel',
              label: 'Cancelar',
              action: OptionAction.cancel,
            ),
          ],
        ));
      case RecipientNotFound(:final suggestions):
        questions.add(Clarification(
          kind: ClarificationKind.recipientNotFound,
          subject: raw,
          allowsFreeText: true,
          question: suggestions.isEmpty
              ? 'No encontré a "$display" entre tus contactos.'
              : 'No encontré a "$display" entre tus contactos. ¿Quisiste decir '
                  '${SpanishFormatter.joinList([for (final s in suggestions) s.displayName])}?',
          options: [
            for (final s in suggestions)
              ClarificationOption(
                id: s.id ?? s.displayName,
                label: s.displayName,
                patch: {
                  PatchKeys.addRecipient: s.toJson(),
                  PatchKeys.resolveRecipient: raw,
                },
              ),
            ClarificationOption(
              id: 'search',
              label: 'Buscar usuarios',
              action: OptionAction.searchUsers,
              patch: {PatchKeys.resolveRecipient: raw},
            ),
            ClarificationOption(
              id: 'invite',
              label: 'Invitar a $display',
              action: OptionAction.inviteUser,
              patch: {PatchKeys.resolveRecipient: raw},
            ),
            const ClarificationOption(
              id: 'cancel',
              label: 'Cancelar',
              action: OptionAction.cancel,
            ),
          ],
        ));
      case RecipientResolved():
        // Se resolvió al revalidar (p. ej. el contacto se agregó después):
        // el intérprete lo incorpora en el siguiente paso.
        break;
    }
  }

  /// Vuelve a resolver un destinatario pendiente a partir de su texto.
  RecipientMatch _resolveRaw(String raw, InterpretationContext ctx) {
    final key = TextNormalizer.nameKey(raw);
    if (raw.startsWith('@')) return _recipients.resolveUsername(raw, ctx);
    if (_isGroupRaw(raw)) {
      return _recipients.resolveGroup(key, ctx);
    }
    return _recipients.resolve(
      RecipientMention(raw: raw, key: key, kind: RecipientMentionKind.person),
      ctx,
    );
  }

  RecipientMatch resolvePending(String raw, InterpretationContext ctx) =>
      _resolveRaw(raw, ctx);

  static String _displayRaw(String raw) =>
      raw.replaceFirst(RegExp(r'^grupo\s+', caseSensitive: false), '');

  static bool _isGroupRaw(String raw) {
    final key = TextNormalizer.nameKey(raw);
    return key.startsWith('grupo') || key.startsWith('equipo');
  }

  // --------------------------------------------------------------- objetivo

  void _validateTarget(
    CommandDraft draft,
    InterpretationContext ctx,
    List<ValidationIssue> issues,
    List<Clarification> questions,
  ) {
    final target = draft.target ?? const AlarmTarget();
    if (target.alarmId != null) return;
    final matches = _alarms.match(target, draft.intent, ctx.alarms);
    if (matches.isEmpty) {
      final what = _describeTarget(target, ctx);
      issues.add(ValidationIssue(
        'alarm_not_found',
        what == null
            ? 'No tienes alarmas que pueda ${_verb(draft.intent)}.'
            : 'No encontré ninguna alarma $what.',
      ));
      return;
    }
    questions.add(Clarification(
      kind: ClarificationKind.alarmAmbiguous,
      question: '¿Qué alarma quieres ${_verb(draft.intent)}?',
      options: [
        for (final alarm in matches.take(8))
          ClarificationOption(
            id: alarm.alarmId,
            label: _alarmLabel(alarm, ctx),
            patch: {
              PatchKeys.targetAlarmId: alarm.alarmId,
              PatchKeys.targetAlarmTitle: alarm.title,
            },
          ),
      ],
    ));
  }

  static String _verb(CommandIntent intent) => switch (intent) {
        CommandIntent.editAlarm => 'modificar',
        CommandIntent.deleteAlarm => 'eliminar',
        CommandIntent.cancelAlarm => 'desactivar',
        CommandIntent.snoozeAlarm => 'posponer',
        _ => 'usar',
      };

  static String? _describeTarget(AlarmTarget target, InterpretationContext ctx) {
    final parts = <String>[];
    if (target.times.isNotEmpty) {
      parts.add('a las ${target.times.map(SpanishFormatter.shortTime).join(' ni a las ')}');
    }
    if (target.date != null) {
      parts.add('para ${SpanishFormatter.date(target.date!, ctx.today).toLowerCase()}');
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  static String _alarmLabel(AlarmCandidate alarm, InterpretationContext ctx) {
    final when = alarm.nextOccurrence == null
        ? SpanishFormatter.shortTime(alarm.time)
        : '${SpanishFormatter.date(alarm.nextOccurrence!.date, ctx.today)} '
            '${SpanishFormatter.shortTime(alarm.nextOccurrence!.time)}';
    return '$when · ${alarm.title}';
  }

  void _validateEditChanges(
    CommandDraft draft,
    InterpretationContext ctx,
    List<ValidationIssue> issues,
    List<Clarification> questions,
  ) {
    if (draft.timeOptions.isNotEmpty) {
      questions.add(_meridiemQuestion(draft.timeOptions, ctx, recurring: true));
      return;
    }
    final hasChange = draft.time != null ||
        draft.date != null ||
        draft.message != null ||
        draft.repeat != null;
    if (!hasChange) {
      issues.add(const ValidationIssue(
        'nothing_to_change',
        'Dime qué quieres cambiar, por ejemplo: "cambia la alarma de las 8 a las 9".',
      ));
    }
  }

  // ---------------------------------------------------------------- posponer

  void _validateSnooze(
    CommandDraft draft,
    List<ValidationIssue> issues,
    List<Clarification> questions,
  ) {
    final minutes = draft.snoozeMinutes;
    if (minutes == null) {
      questions.add(Clarification(
        kind: ClarificationKind.snoozeDuration,
        question: '¿Cuánto tiempo quieres posponerla?',
        allowsFreeText: true,
        options: [
          for (final m in const [5, 10, 15, 30])
            ClarificationOption(
              id: '$m',
              label: SpanishFormatter.duration(m),
              patch: {PatchKeys.snoozeMinutes: m},
            ),
        ],
      ));
    } else if (minutes < 1 || minutes > maxSnoozeMinutes) {
      issues.add(const ValidationIssue(
        'invalid_snooze',
        'Puedo posponer una alarma entre 1 minuto y 24 horas.',
      ));
    }
  }

  // ------------------------------------------------------------------ grupos

  void _validateGroupName(
    CommandDraft draft,
    List<ValidationIssue> issues,
    List<Clarification> questions,
  ) {
    final name = draft.groupName?.trim() ?? '';
    if (name.isEmpty) {
      questions.add(const Clarification(
        kind: ClarificationKind.missingGroupName,
        question: '¿Cómo quieres llamar al grupo?',
        allowsFreeText: true,
      ));
    } else if (name.length > maxGroupNameLength) {
      issues.add(const ValidationIssue(
        'group_name_too_long',
        'El nombre del grupo puede tener como máximo 60 caracteres.',
      ));
    }
  }

  void _validateGroupReference(
    CommandDraft draft,
    InterpretationContext ctx,
    List<Clarification> questions,
  ) {
    if (draft.groupId != null) return;
    final match = _recipients.resolveGroup(draft.groupName ?? '', ctx);
    switch (match) {
      case RecipientAmbiguous(:final candidates):
        questions.add(Clarification(
          kind: ClarificationKind.groupAmbiguous,
          question: '¿En qué grupo?',
          options: [
            for (final g in candidates)
              ClarificationOption(
                id: g.id!,
                label: g.displayName,
                patch: {PatchKeys.groupId: g.id, PatchKeys.groupName: g.displayName},
              ),
          ],
        ));
      case RecipientNotFound():
        questions.add(Clarification(
          kind: ClarificationKind.groupNotFound,
          question: draft.groupName == null || draft.groupName!.isEmpty
              ? '¿En qué grupo?'
              : 'No encontré el grupo "${draft.groupName}". ¿Cuál es su nombre?',
          allowsFreeText: true,
          options: [
            for (final g in ctx.groups.take(8))
              ClarificationOption(
                id: g.groupId,
                label: g.name,
                patch: {PatchKeys.groupId: g.groupId, PatchKeys.groupName: g.name},
              ),
          ],
        ));
      case RecipientResolved():
        break;
    }
  }

  void _validateMembers(
    CommandDraft draft,
    InterpretationContext ctx,
    List<Clarification> questions, {
    required bool required,
  }) {
    if (draft.unresolvedMembers.isNotEmpty) {
      final raw = draft.unresolvedMembers.first;
      final match = raw.startsWith('@')
          ? _recipients.resolveUsername(raw, ctx)
          : _recipients.resolvePerson(raw, ctx);
      final candidates = switch (match) {
        RecipientAmbiguous(:final candidates) => candidates,
        RecipientNotFound(:final suggestions) => suggestions,
        RecipientResolved(:final recipient) => [recipient],
      };
      questions.add(Clarification(
        kind: match is RecipientAmbiguous
            ? ClarificationKind.memberAmbiguous
            : ClarificationKind.memberNotFound,
        subject: raw,
        allowsFreeText: true,
        question: match is RecipientAmbiguous
            ? 'Encontré varios contactos llamados $raw. ¿A cuál te refieres?'
            : 'No encontré a "$raw" entre tus contactos.',
        options: [
          for (final c in candidates)
            ClarificationOption(
              id: c.id ?? c.displayName,
              label: c.displayName,
              patch: {PatchKeys.addMember: c.toJson(), PatchKeys.resolveMember: raw},
            ),
          ClarificationOption(
            id: 'skip',
            label: 'Omitir a $raw',
            patch: {PatchKeys.resolveMember: raw},
          ),
        ],
      ));
      return;
    }
    if (required && draft.members.isEmpty) {
      questions.add(const Clarification(
        kind: ClarificationKind.missingMembers,
        question: '¿A quién?',
        allowsFreeText: true,
      ));
    }
  }
}
