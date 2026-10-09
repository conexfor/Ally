import '../model/command_draft.dart';
import '../model/command_intent.dart';
import '../model/interpretation_context.dart';
import '../model/mentions.dart';
import '../model/parsed_command.dart';
import '../text_normalizer.dart';
import 'alarm_matcher.dart';
import 'recipient_resolver.dart';
import 'schedule_resolver.dart';

/// Convierte el análisis sintáctico en un [CommandDraft] resolviendo fechas,
/// horas, destinatarios y alarmas referenciadas contra el contexto.
class DraftBuilder {
  final ScheduleResolver _schedule;
  final RecipientResolver _recipients;
  final AlarmMatcher _alarms;

  const DraftBuilder({
    ScheduleResolver schedule = const ScheduleResolver(),
    RecipientResolver recipients = const RecipientResolver(),
    AlarmMatcher alarms = const AlarmMatcher(),
  })  : _schedule = schedule,
        _recipients = recipients,
        _alarms = alarms;

  CommandDraft build(ParsedCommand parsed, InterpretationContext ctx) {
    final base = CommandDraft(
      intent: parsed.intent,
      originalText: parsed.originalText,
      unrecognizedWords: parsed.unrecognizedWords,
      intentInferred: !parsed.intentExplicit,
      message: parsed.message,
    );
    return switch (parsed.intent) {
      CommandIntent.createAlarm => _buildCreate(base, parsed, ctx),
      CommandIntent.editAlarm => _buildEdit(base, parsed, ctx),
      CommandIntent.deleteAlarm || CommandIntent.cancelAlarm => base.copyWith(
          target: _schedule.resolveTarget(parsed, ctx, onlyReferences: false),
        ),
      CommandIntent.snoozeAlarm => base.copyWith(
          target: _schedule.resolveTarget(parsed, ctx, onlyReferences: false),
          snoozeMinutes: parsed.durationMinutes,
        ),
      CommandIntent.listAlarms => _buildList(base, parsed, ctx),
      CommandIntent.createGroup ||
      CommandIntent.addMember ||
      CommandIntent.removeMember =>
        _buildGroupCommand(base, parsed, ctx),
      _ => base,
    };
  }

  CommandDraft _buildCreate(
    CommandDraft base,
    ParsedCommand parsed,
    InterpretationContext ctx,
  ) {
    final schedule = _schedule.resolveForCreate(parsed, ctx);
    final resolved = <ResolvedRecipient>[];
    final unresolved = <String>[];
    var message = parsed.message;

    for (final segment in parsed.recipientSegments) {
      final results = [
        for (final item in segment.items) ..._resolveItem(item, ctx),
      ];
      // "para despertar", "para la reunión con el cliente": no son personas
      // sino el motivo de la alarma.
      final nothingMatched = results.every(
        (r) => r.$2 is RecipientNotFound &&
            (r.$2 as RecipientNotFound).suggestions.isEmpty,
      );
      final first = segment.items.first;
      if (nothingMatched && segment.tentative) {
        // "con sonido suave": no es un destinatario.
        message ??= _purposeText('con ${segment.originalText}');
        continue;
      }
      if (nothingMatched &&
          message == null &&
          first.kind == RecipientMentionKind.person &&
          (first.looksLikeInfinitive || first.hadArticle)) {
        message = _purposeText(segment.originalText);
        continue;
      }
      for (final (item, match) in results) {
        switch (match) {
          case RecipientResolved(:final recipient):
            _addUnique(resolved, recipient);
          case RecipientAmbiguous() || RecipientNotFound():
            unresolved.add(_unresolvedKey(item));
        }
      }
    }

    // Quien crea la alarma siempre la recibe (también si es para otros); los
    // demás solo suenan cuando la aceptan. Se puede quitar en el formulario.
    final self = RecipientResolver.self(ctx);
    if (!resolved.any((r) => r.sameAs(self))) resolved.insert(0, self);

    return base.copyWith(
      date: schedule.date,
      time: schedule.time,
      dateInferred: schedule.dateInferred,
      timeOptions: schedule.timeOptions,
      period: schedule.period,
      repeat: schedule.repeat,
      invalidDate: schedule.invalidDate,
      recipients: resolved,
      unresolvedRecipients: unresolved,
      message: message,
    );
  }

  CommandDraft _buildEdit(
    CommandDraft base,
    ParsedCommand parsed,
    InterpretationContext ctx,
  ) {
    var target = _schedule.resolveTarget(parsed, ctx, onlyReferences: true);
    final matches = _alarms.match(target, CommandIntent.editAlarm, ctx.alarms);
    final current = matches.length == 1 ? matches.single : null;
    if (current != null) target = target.withAlarm(current.alarmId, current.title);

    final values = _schedule.resolveEditValues(
      parsed,
      ctx,
      currentTime: current?.time,
    );
    return base.copyWith(
      target: target,
      date: values.date,
      time: values.time,
      timeOptions: values.timeOptions,
      repeat: values.repeat,
      invalidDate: values.invalidDate,
    );
  }

  CommandDraft _buildList(
    CommandDraft base,
    ParsedCommand parsed,
    InterpretationContext ctx,
  ) {
    final dateMention = parsed.dates.isEmpty ? null : parsed.dates.first;
    return base.copyWith(
      date: dateMention == null
          ? null
          : ScheduleResolver.resolveDate(dateMention, ctx.today),
      period: parsed.standalonePeriod ?? dateMention?.period,
    );
  }

  CommandDraft _buildGroupCommand(
    CommandDraft base,
    ParsedCommand parsed,
    InterpretationContext ctx,
  ) {
    String? groupId;
    var groupName = parsed.groupName;
    if (parsed.intent != CommandIntent.createGroup && groupName != null) {
      final match = _recipients.resolveGroup(groupName, ctx);
      if (match is RecipientResolved) {
        groupId = match.recipient.id;
        groupName = match.recipient.displayName;
      }
    }

    final members = <ResolvedRecipient>[];
    final unresolved = <String>[];
    for (final item in [for (final s in parsed.memberSegments) ...s.items]) {
      final match = item.kind == RecipientMentionKind.username
          ? _recipients.resolveUsername(item.key, ctx)
          : _recipients.resolvePerson(item.key, ctx);
      if (match is RecipientResolved) {
        _addUnique(members, match.recipient);
      } else {
        unresolved.add(item.raw);
      }
    }
    return base.copyWith(
      groupId: groupId,
      groupName: groupName,
      members: members,
      unresolvedMembers: unresolved,
    );
  }

  /// Resuelve una mención. Si no coincide y tiene varias palabras, prueba a
  /// leerla como varios nombres sin comas ("Ana Luis y Pedro", típico del
  /// dictado por voz): solo se acepta si todas las palabras encajan.
  List<(RecipientMention, RecipientMatch)> _resolveItem(
    RecipientMention item,
    InterpretationContext ctx,
  ) {
    final match = _recipients.resolve(item, ctx);
    if (match is! RecipientNotFound || item.kind != RecipientMentionKind.person) {
      return [(item, match)];
    }
    final keys = item.key.split(' ');
    if (keys.length < 2) return [(item, match)];
    final raws = item.raw.split(RegExp(r'\s+'));
    final words = raws.length == keys.length ? raws : keys;

    final parts = <(RecipientMention, RecipientMatch)>[];
    var start = 0;
    while (start < keys.length) {
      (RecipientMention, RecipientMatch)? best;
      // La secuencia más larga primero: "Juan Pérez María" → "Juan Pérez", "María".
      for (var end = keys.length; end > start; end--) {
        if (start == 0 && end == keys.length) continue;
        final raw = words.sublist(start, end).join(' ');
        final part = RecipientMention(
          raw: raw,
          key: TextNormalizer.nameKey(raw),
          kind: RecipientMentionKind.person,
        );
        final partMatch = _recipients.resolvePerson(part.key, ctx);
        if (partMatch is! RecipientNotFound) {
          best = (part, partMatch);
          start = end;
          break;
        }
      }
      if (best == null) return [(item, match)];
      parts.add(best);
    }
    return parts;
  }

  static void _addUnique(List<ResolvedRecipient> list, ResolvedRecipient r) {
    if (!list.any((x) => x.sameAs(r))) list.add(r);
  }

  /// Texto con el que se vuelve a resolver un destinatario pendiente.
  static String _unresolvedKey(RecipientMention item) => switch (item.kind) {
        RecipientMentionKind.username => item.raw,
        RecipientMentionKind.group =>
          item.key.startsWith('grupo') || item.key.startsWith('equipo')
              ? item.raw
              : 'grupo ${item.raw}',
        RecipientMentionKind.person => item.raw,
      };

  static String _purposeText(String segment) {
    final text = segment
        .trim()
        .replaceFirst(RegExp(r'^(?:el|la|los|las|un|una)\s+', caseSensitive: false), '');
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }
}
