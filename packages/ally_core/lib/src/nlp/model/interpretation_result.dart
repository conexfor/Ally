import 'command_draft.dart';

enum ClarificationKind {
  meridiem('meridiem'),
  missingTime('missing_time'),
  pastDateTime('past_date_time'),
  recipientAmbiguous('recipient_ambiguous'),
  recipientNotFound('recipient_not_found'),
  groupAmbiguous('group_ambiguous'),
  groupNotFound('group_not_found'),
  memberAmbiguous('member_ambiguous'),
  memberNotFound('member_not_found'),
  missingGroupName('missing_group_name'),
  missingMembers('missing_members'),
  alarmAmbiguous('alarm_ambiguous'),
  alarmNotFound('alarm_not_found'),
  snoozeDuration('snooze_duration');

  const ClarificationKind(this.wire);
  final String wire;
  static ClarificationKind fromWire(String w) =>
      values.firstWhere((v) => v.wire == w);
}

/// Acción de interfaz asociada a una opción (además de modificar el borrador).
enum OptionAction {
  none('none'),
  searchUsers('search_users'),
  inviteUser('invite_user'),
  cancel('cancel');

  const OptionAction(this.wire);
  final String wire;
  static OptionAction fromWire(String w) =>
      values.firstWhere((v) => v.wire == w, orElse: () => OptionAction.none);
}

/// Opción que el usuario puede elegir para resolver una aclaración.
///
/// [patch] describe cómo modificar el borrador (ver `DraftPatcher`).
class ClarificationOption {
  final String id;
  final String label;
  final Map<String, dynamic> patch;
  final OptionAction action;

  const ClarificationOption({
    required this.id,
    required this.label,
    this.patch = const {},
    this.action = OptionAction.none,
  });

  factory ClarificationOption.fromJson(Map<String, dynamic> json) =>
      ClarificationOption(
        id: json['id'] as String,
        label: json['label'] as String,
        patch: Map<String, dynamic>.from(json['patch'] as Map? ?? const {}),
        action: OptionAction.fromWire(json['action'] as String? ?? 'none'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'patch': patch,
        'action': action.wire,
      };
}

/// Pregunta que el asistente necesita hacer antes de continuar.
class Clarification {
  final ClarificationKind kind;
  final String question;
  final List<ClarificationOption> options;

  /// El usuario puede responder escribiendo (p. ej. una hora).
  final bool allowsFreeText;

  /// Elemento al que se refiere (p. ej. el nombre "Carlos").
  final String? subject;

  const Clarification({
    required this.kind,
    required this.question,
    this.options = const [],
    this.allowsFreeText = false,
    this.subject,
  });

  factory Clarification.fromJson(Map<String, dynamic> json) => Clarification(
        kind: ClarificationKind.fromWire(json['kind'] as String),
        question: json['question'] as String,
        options: [
          for (final o in (json['options'] as List? ?? const []))
            ClarificationOption.fromJson(o as Map<String, dynamic>),
        ],
        allowsFreeText: json['allows_free_text'] as bool? ?? false,
        subject: json['subject'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.wire,
        'question': question,
        'options': [for (final o in options) o.toJson()],
        'allows_free_text': allowsFreeText,
        if (subject != null) 'subject': subject,
      };
}

enum IssueSeverity { error, warning }

/// Problema detectado al validar (mensaje apto para el usuario).
class ValidationIssue {
  final String code;
  final String message;
  final IssueSeverity severity;

  const ValidationIssue(this.code, this.message,
      {this.severity = IssueSeverity.error});

  factory ValidationIssue.fromJson(Map<String, dynamic> json) =>
      ValidationIssue(
        json['code'] as String,
        json['message'] as String,
        severity: json['severity'] == 'warning'
            ? IssueSeverity.warning
            : IssueSeverity.error,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'severity': severity.name,
      };
}

enum SummaryLineKind {
  time('time'),
  date('date'),
  recipient('recipient'),
  group('group'),
  message('message'),
  repeat('repeat'),
  snooze('snooze'),
  target('target'),
  members('members');

  const SummaryLineKind(this.wire);
  final String wire;

  String get emoji => switch (this) {
        time => '⏰',
        date => '📅',
        recipient => '👤',
        group => '👥',
        message => '📝',
        repeat => '🔁',
        snooze => '😴',
        target => '🔔',
        members => '👥',
      };

  static SummaryLineKind fromWire(String w) =>
      values.firstWhere((v) => v.wire == w);
}

class SummaryLine {
  final SummaryLineKind kind;
  final String text;
  const SummaryLine(this.kind, this.text);

  factory SummaryLine.fromJson(Map<String, dynamic> json) => SummaryLine(
        SummaryLineKind.fromWire(json['kind'] as String),
        json['text'] as String,
      );

  Map<String, dynamic> toJson() => {'kind': kind.wire, 'text': text};
}

/// Resumen que se muestra antes de ejecutar una operación.
class ConfirmationSummary {
  final String title;
  final List<SummaryLine> lines;
  final String question;
  final String confirmLabel;
  final String cancelLabel;

  /// No se entendió todo: se muestra "No entendí completamente la
  /// instrucción" y se ofrece [Editar] en lugar de [Cancelar].
  final bool partial;

  /// Operación destructiva (eliminar, quitar miembro).
  final bool destructive;

  const ConfirmationSummary({
    required this.title,
    required this.lines,
    required this.question,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.partial = false,
    this.destructive = false,
  });

  /// Versión en texto plano (para el historial del chat).
  String toPlainText() {
    final buffer = StringBuffer();
    if (partial) {
      buffer
        ..writeln('No entendí completamente la instrucción.')
        ..writeln()
        ..writeln('Encontré:');
    } else {
      buffer.writeln(title);
    }
    buffer.writeln();
    for (final line in lines) {
      buffer.writeln('${line.kind.emoji} ${line.text}');
    }
    buffer
      ..writeln()
      ..write(question);
    return buffer.toString();
  }

  factory ConfirmationSummary.fromJson(Map<String, dynamic> json) =>
      ConfirmationSummary(
        title: json['title'] as String,
        lines: [
          for (final l in (json['lines'] as List? ?? const []))
            SummaryLine.fromJson(l as Map<String, dynamic>),
        ],
        question: json['question'] as String,
        confirmLabel: json['confirm_label'] as String? ?? 'Confirmar',
        cancelLabel: json['cancel_label'] as String? ?? 'Cancelar',
        partial: json['partial'] as bool? ?? false,
        destructive: json['destructive'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'lines': [for (final l in lines) l.toJson()],
        'question': question,
        'confirm_label': confirmLabel,
        'cancel_label': cancelLabel,
        'partial': partial,
        'destructive': destructive,
      };
}

enum InterpretationStatus {
  /// Falta información: hay que responder a [InterpretationResult.clarifications].
  needsClarification('needs_clarification'),

  /// Todo listo: mostrar [InterpretationResult.confirmation] y esperar confirmación.
  needsConfirmation('needs_confirmation'),

  /// Consulta o ayuda: se puede ejecutar directamente (no modifica datos).
  readyToExecute('ready_to_execute'),

  /// El comando no es válido (ver [InterpretationResult.issues]).
  invalid('invalid'),

  /// No se entendió el texto.
  notUnderstood('not_understood');

  const InterpretationStatus(this.wire);
  final String wire;
  static InterpretationStatus fromWire(String w) =>
      values.firstWhere((v) => v.wire == w);
}

/// Salida del intérprete: borrador + lo que falta para ejecutarlo.
class InterpretationResult {
  final CommandDraft draft;
  final InterpretationStatus status;
  final List<Clarification> clarifications;
  final List<ValidationIssue> issues;
  final ConfirmationSummary? confirmation;

  /// Respuesta breve para el usuario (pregunta, error o resumen).
  final String reply;

  const InterpretationResult({
    required this.draft,
    required this.status,
    required this.reply,
    this.clarifications = const [],
    this.issues = const [],
    this.confirmation,
  });

  /// Primera aclaración pendiente (se preguntan de una en una).
  Clarification? get pendingClarification =>
      clarifications.isEmpty ? null : clarifications.first;

  factory InterpretationResult.fromJson(Map<String, dynamic> json) =>
      InterpretationResult(
        draft: CommandDraft.fromJson(json['draft'] as Map<String, dynamic>),
        status: InterpretationStatus.fromWire(json['status'] as String),
        reply: json['reply'] as String? ?? '',
        clarifications: [
          for (final c in (json['clarifications'] as List? ?? const []))
            Clarification.fromJson(c as Map<String, dynamic>),
        ],
        issues: [
          for (final i in (json['issues'] as List? ?? const []))
            ValidationIssue.fromJson(i as Map<String, dynamic>),
        ],
        confirmation: json['confirmation'] == null
            ? null
            : ConfirmationSummary.fromJson(
                json['confirmation'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'status': status.wire,
        'reply': reply,
        'draft': draft.toJson(),
        'clarifications': [for (final c in clarifications) c.toJson()],
        'issues': [for (final i in issues) i.toJson()],
        'confirmation': confirmation?.toJson(),
      };
}
