import 'package:ally_core/ally_core.dart';

/// Reglas del asistente cuando se usa por voz (manos libres).
abstract final class VoicePolicy {
  /// Por voz las alarmas se crean directamente, sin pedir confirmación,
  /// siempre que se haya entendido toda la orden. Lo demás (eliminar,
  /// cambiar...) sí se confirma diciendo «sí».
  ///
  /// Excepción: una hora que acaba de pasar hoy («a las 11:13» dicho a las
  /// 11:13) se pregunta antes de ponerla para mañana (ver [justPassed]).
  ///
  /// Tras decir «Hey Ally», una hora sola («a las 9:18») ya es una orden de
  /// alarma: si solo faltaba la palabra «alarma» también se crea directamente.
  static bool autoExecutes(InterpretationResult r, {DateTime? now}) =>
      r.status == InterpretationStatus.needsConfirmation &&
      r.draft.intent == CommandIntent.createAlarm &&
      (!(r.confirmation?.partial ?? true) || _onlyMissingVerb(r.draft)) &&
      !justPassed(r, now: now);

  /// Se entendió la hora y no sobra nada: lo único "parcial" es que no se dijo
  /// «alarma» ni un verbo («pon», «crea»...).
  static bool _onlyMissingVerb(CommandDraft d) =>
      d.intentInferred && d.unrecognizedWords.length < 2 && d.time != null && d.date != null;

  /// La hora pedida ya pasó hoy hace menos de una hora y, como no se dijo el
  /// día, el intérprete la movió a mañana. Casi seguro el usuario no quería
  /// mañana (p. ej. está probando la app): mejor preguntar.
  static bool justPassed(InterpretationResult r, {DateTime? now}) {
    final d = r.draft;
    final date = d.date;
    final time = d.time;
    if (!d.dateInferred || date == null || time == null || d.repeat != null) return false;
    final ahora = now ?? DateTime.now();
    if (date != LocalDate.fromDateTime(ahora).addDays(1)) return false;
    final transcurridos = (ahora.hour * 60 + ahora.minute) - (time.hour * 60 + time.minute);
    return transcurridos >= 0 && transcurridos <= 60;
  }

  /// Texto que se lee en voz alta para una interpretación pendiente.
  static String speech(InterpretationResult r, {DateTime? now}) {
    if (r.status == InterpretationStatus.needsConfirmation && justPassed(r, now: now)) {
      final hora = clean(SpanishFormatter.time(r.draft.time!));
      return 'Las $hora ya pasaron hoy. ¿La pongo para mañana a esa hora? '
          'Si quieres que suene pronto, di por ejemplo «alarma en 2 minutos».';
    }
    final clarification = r.pendingClarification;
    if (r.status == InterpretationStatus.needsClarification && clarification != null) {
      final question = clean(r.reply.isEmpty ? clarification.question : r.reply);
      final options = [
        for (final o in clarification.options)
          if (o.action == OptionAction.none) clean(o.label),
      ];
      // Las opciones se leen si no están ya en la pregunta (p. ej. «¿Carlos
      // Pérez o Carlos Torres?» sí; «¿6 PM o 6 AM?» ya las incluye).
      if (options.isNotEmpty && options.length <= 4 && !options.every(question.contains)) {
        return '$question ${_joinOr(options)}.';
      }
      return question;
    }
    final c = r.confirmation;
    if (c != null && r.draft.intent == CommandIntent.createAlarm) {
      // Una frase natural, no el resumen línea a línea («Entendí. 9:18. Hoy. Tú.»).
      final describe = _describe(c.lines);
      return c.partial ? 'No entendí todo. ¿Quieres una alarma$describe?' : '¿Creo una alarma$describe?';
    }
    if (c != null) {
      return [
        c.partial ? 'No entendí todo. Entendí' : c.title,
        for (final line in c.lines) line.text,
        c.question,
      ].map(clean).where((s) => s.isNotEmpty).join('. ');
    }
    return clean(r.reply);
  }

  /// «Listo. Alarma creada para hoy a las 4 de la tarde para Ana, Luis y Pedro.»
  static String created(InterpretationResult r, String executionReply) {
    final buffer = StringBuffer('Listo. Alarma creada${_describe(r.confirmation?.lines ?? const [])}.');
    // Avisos del resultado ("X debe aceptarla", "sin conexión...").
    final extra = executionReply.split('\n').skip(1).map(clean).where((s) => s.isNotEmpty);
    for (final e in extra) {
      buffer.write(' $e');
    }
    return buffer.toString();
  }

  /// «, hoy, a las 9:18 de la mañana, para Ana y Luis» (sin «para ti» si la
  /// alarma es solo tuya).
  static String _describe(List<SummaryLine> lines) {
    String? line(SummaryLineKind kind) {
      for (final l in lines) {
        if (l.kind == kind) return clean(l.text);
      }
      return null;
    }

    final people = [
      for (final l in lines)
        if (l.kind == SummaryLineKind.recipient || l.kind == SummaryLineKind.group)
          l.text == 'Tú' ? 'ti' : clean(l.text),
    ];
    final buffer = StringBuffer();
    final repeat = line(SummaryLineKind.repeat);
    final date = line(SummaryLineKind.date);
    if (repeat != null) {
      buffer.write(', ${repeat.toLowerCase()}');
    } else if (date != null) {
      buffer.write(', ${date.toLowerCase()}');
    }
    final time = line(SummaryLineKind.time);
    if (time != null) buffer.write(RegExp(r'^1\b').hasMatch(time) ? ', a la $time' : ', a las $time');
    // «Para ti» sobra cuando la alarma es solo tuya.
    if (people.isNotEmpty && !(people.length == 1 && people.single == 'ti')) {
      buffer.write(', para ${SpanishFormatter.joinList(people)}');
    }
    return buffer.toString();
  }

  static final _emoji = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
    unicode: true,
  );
  static final _clock = RegExp(r'\b0?(\d{1,2}):(\d{2})\s*([AP])\.?\s?M\.?(?![a-z])', caseSensitive: false);

  /// Quita emojis, viñetas y saltos de línea, y escribe las horas como se
  /// dicen («04:00 PM» → «4 de la tarde»).
  static String clean(String text) {
    var s = text.replaceAll(_emoji, '').replaceAll('•', '').replaceAll('—', ',');
    s = s.replaceAllMapped(_clock, (m) {
      final h12 = int.parse(m[1]!);
      final minutes = int.parse(m[2]!);
      final pm = m[3]!.toUpperCase() == 'P';
      final hour24 = (h12 % 12) + (pm ? 12 : 0);
      return _spokenTime(h12, minutes, hour24);
    });
    // Cada línea se lee como una frase.
    final lines = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    s = [
      for (var i = 0; i < lines.length; i++)
        i < lines.length - 1 && !RegExp(r'[.:?!,]$').hasMatch(lines[i]) ? '${lines[i]}.' : lines[i],
    ].join(' ');
    return s
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([.,;:?!])'), (m) => m[1]!)
        .trim();
  }

  static String _spokenTime(int h12, int minutes, int hour24) {
    // «9 y 23», no «9:23»: el motor de voz lee «9:23» como hora y añade por su
    // cuenta «de la mañana» (se oía «9:23 de la mañana de la mañana»).
    final clock = minutes == 0 ? '$h12' : '$h12 y $minutes';
    final period = switch (hour24) {
      0 => 'de la medianoche', // 12:06 AM → «12 y 6 de la medianoche»
      12 => 'del mediodía', // 12:30 PM → «12 y 30 del mediodía»
      < 6 => 'de la madrugada',
      < 12 => 'de la mañana',
      < 19 => 'de la tarde',
      _ => 'de la noche',
    };
    return '$clock $period';
  }

  static String _joinOr(List<String> items) =>
      items.length == 1 ? items.single : '${items.sublist(0, items.length - 1).join(', ')} o ${items.last}';
}
