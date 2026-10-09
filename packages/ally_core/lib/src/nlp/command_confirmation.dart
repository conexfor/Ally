import 'model/command_draft.dart';
import 'model/command_intent.dart';
import 'model/interpretation_context.dart';
import 'model/interpretation_result.dart';
import 'spanish_formatter.dart';

/// Construye el resumen que se muestra antes de ejecutar una operación:
///
/// ```text
/// Nueva alarma
/// ⏰ 08:00 AM
/// 📅 Mañana
/// 👤 Nicolás
/// ¿Quieres crearla?
/// ```
class CommandConfirmation {
  const CommandConfirmation();

  ConfirmationSummary? build(CommandDraft draft, InterpretationContext ctx) {
    final summary = switch (draft.intent) {
      CommandIntent.createAlarm => _create(draft, ctx),
      CommandIntent.editAlarm => _edit(draft, ctx),
      CommandIntent.deleteAlarm => _simpleTarget(
          draft,
          title: 'Eliminar alarma',
          question: '¿Quieres eliminarla? Se cancelará para todos los destinatarios.',
          confirm: 'Eliminar',
          destructive: true,
        ),
      CommandIntent.cancelAlarm => _simpleTarget(
          draft,
          title: 'Desactivar alarma',
          question: '¿Quieres desactivar la próxima vez que suene?',
          confirm: 'Desactivar',
        ),
      CommandIntent.snoozeAlarm => _snooze(draft),
      CommandIntent.createGroup => _createGroup(draft),
      CommandIntent.addMember => _member(draft, adding: true),
      CommandIntent.removeMember => _member(draft, adding: false),
      _ => null,
    };
    return summary;
  }

  ConfirmationSummary _create(CommandDraft draft, InterpretationContext ctx) {
    final lines = <SummaryLine>[
      if (draft.time != null)
        SummaryLine(SummaryLineKind.time, SpanishFormatter.time(draft.time!)),
      if (draft.repeat != null)
        SummaryLine(SummaryLineKind.repeat, SpanishFormatter.repeat(draft.repeat!))
      else if (draft.date != null)
        SummaryLine(SummaryLineKind.date, SpanishFormatter.date(draft.date!, ctx.today)),
      for (final r in draft.recipients)
        SummaryLine(
          r.type == ResolvedRecipientType.group
              ? SummaryLineKind.group
              : SummaryLineKind.recipient,
          r.displayName,
        ),
      if (draft.message != null)
        SummaryLine(SummaryLineKind.message, draft.message!),
    ];
    return ConfirmationSummary(
      title: 'Nueva alarma',
      lines: lines,
      question: draft.isPartial ? '¿Quieres continuar?' : '¿Quieres crearla?',
      partial: draft.isPartial,
      cancelLabel: draft.isPartial ? 'Editar' : 'Cancelar',
    );
  }

  ConfirmationSummary _edit(CommandDraft draft, InterpretationContext ctx) {
    final lines = <SummaryLine>[
      SummaryLine(SummaryLineKind.target, draft.target?.alarmTitle ?? 'Alarma'),
      if (draft.time != null)
        SummaryLine(SummaryLineKind.time, 'Nueva hora: ${SpanishFormatter.time(draft.time!)}'),
      if (draft.date != null)
        SummaryLine(
          SummaryLineKind.date,
          'Nueva fecha: ${SpanishFormatter.date(draft.date!, ctx.today)}',
        ),
      if (draft.repeat != null)
        SummaryLine(SummaryLineKind.repeat, SpanishFormatter.repeat(draft.repeat!)),
      if (draft.message != null)
        SummaryLine(SummaryLineKind.message, 'Nuevo mensaje: ${draft.message}'),
    ];
    return ConfirmationSummary(
      title: 'Modificar alarma',
      lines: lines,
      question: '¿Quieres guardar los cambios?',
      confirmLabel: 'Guardar',
      partial: draft.isPartial,
    );
  }

  ConfirmationSummary _simpleTarget(
    CommandDraft draft, {
    required String title,
    required String question,
    required String confirm,
    bool destructive = false,
  }) =>
      ConfirmationSummary(
        title: title,
        lines: [SummaryLine(SummaryLineKind.target, draft.target?.alarmTitle ?? 'Alarma')],
        question: question,
        confirmLabel: confirm,
        destructive: destructive,
      );

  ConfirmationSummary _snooze(CommandDraft draft) => ConfirmationSummary(
        title: 'Posponer alarma',
        lines: [
          SummaryLine(SummaryLineKind.target, draft.target?.alarmTitle ?? 'Alarma'),
          SummaryLine(
            SummaryLineKind.snooze,
            SpanishFormatter.duration(draft.snoozeMinutes ?? 0),
          ),
        ],
        question: '¿Quieres posponerla?',
        confirmLabel: 'Posponer',
      );

  ConfirmationSummary _createGroup(CommandDraft draft) => ConfirmationSummary(
        title: 'Nuevo grupo',
        lines: [
          SummaryLine(SummaryLineKind.group, draft.groupName ?? ''),
          if (draft.members.isNotEmpty)
            SummaryLine(
              SummaryLineKind.members,
              SpanishFormatter.joinList([for (final m in draft.members) m.displayName]),
            ),
        ],
        question: '¿Quieres crearlo?',
      );

  ConfirmationSummary _member(CommandDraft draft, {required bool adding}) =>
      ConfirmationSummary(
        title: adding ? 'Agregar al grupo' : 'Quitar del grupo',
        lines: [
          SummaryLine(SummaryLineKind.group, draft.groupName ?? ''),
          SummaryLine(
            SummaryLineKind.members,
            SpanishFormatter.joinList([for (final m in draft.members) m.displayName]),
          ),
        ],
        question: adding ? '¿Quieres agregarlos?' : '¿Quieres quitarlos del grupo?',
        confirmLabel: adding ? 'Agregar' : 'Quitar',
        destructive: !adding,
      );
}
