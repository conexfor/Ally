import 'package:ally_core/ally_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('Ejemplos de la especificación', () {
    test('"Crea una alarma mañana a las 8 para Nicolás"', () {
      final r = interpret('Crea una alarma mañana a las 8 para Nicolás');
      expect(r.draft.intent, CommandIntent.createAlarm);
      expect(r.draft.date, date(2026, 10, 4));
      expect(r.draft.time, time(8, 0));
      expect(recipientIds(r), ['u-me', 'u-nicolas']);
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('"Pon una alarma hoy a las 2:30 pm para Nicolás y Juan"', () {
      final r = interpret('Pon una alarma hoy a las 2:30 pm para Nicolás y Juan.');
      expect(r.draft.date, date(2026, 10, 3));
      expect(r.draft.time, time(14, 30));
      expect(recipientIds(r), ['u-me', 'u-nicolas', 'u-juan']);
    });

    test('"Pon una alarma hoy a las 14:30 para Juan y María"', () {
      final r = interpret('Pon una alarma hoy a las 14:30 para Juan y María');
      expect(r.draft.intent, CommandIntent.createAlarm);
      expect(r.draft.date, date(2026, 10, 3));
      expect(r.draft.time, time(14, 30));
      expect(recipientIds(r), ['u-me', 'u-juan', 'u-maria']);
    });

    test('"Todos los lunes a las 9 para el equipo"', () {
      final r = interpret('Todos los lunes a las 9 para el equipo');
      expect(r.draft.intent, CommandIntent.createAlarm);
      expect(r.draft.repeat!.frequency, RepeatFrequency.weekly);
      expect(r.draft.repeat!.daysOfWeek, {DateTime.monday});
      expect(r.draft.time, time(9, 0));
      expect(r.draft.recipients.last.type, ResolvedRecipientType.group);
      expect(recipientIds(r), ['u-me', 'g-dev']);
      // Primera ocurrencia: el lunes 5 de octubre.
      expect(r.draft.date, date(2026, 10, 5));
    });

    test('mensaje entre comillas', () {
      final r = interpret(
        'Crea una alarma mañana a las 8 para Nicolás que diga "Reunión de proyecto".',
      );
      expect(r.draft.message, 'Reunión de proyecto');
      expect(recipientIds(r), ['u-me', 'u-nicolas']);
      expect(r.draft.time, time(8, 0));
    });

    test('flujo final: "... para Juan que diga reunión de proyecto"', () {
      final r = interpret(
        'Crea una alarma mañana a las 8 para Juan que diga reunión de proyecto.',
      );
      expect(r.draft.message, 'Reunión de proyecto');
      expect(r.confirmation!.lines.map((l) => l.text), [
        '08:00 AM',
        'Mañana',
        'Tú',
        'Juan Pérez',
        'Reunión de proyecto',
      ]);
    });
  });

  group('Variaciones para crear', () {
    final cases = <String, (LocalTime, List<String>)>{
      'Crea una alarma a las 11 para Nicolás': (time(11, 0), ['u-nicolas']),
      'Pon una alarma mañana a las 7 para Juan': (time(7, 0), ['u-juan']),
      'Alarma para María a las 2:30 pm': (time(14, 30), ['u-maria']),
      'Recuérdale a Nicolás a las 5 de la tarde': (time(17, 0), ['u-nicolas']),
      'Programa una alarma para Pedro mañana a las 9': (time(9, 0), ['u-pedro']),
      'Despierta a Juan mañana a las 6:15 am': (time(6, 15), ['u-juan']),
      'Avísale a María a las 3 de la tarde': (time(15, 0), ['u-maria']),
      'Pon una alarma para @juan mañana a las 10': (time(10, 0), ['u-juan']),
      'PON UNA ALARMA MAÑANA A LAS 8 PARA NICOLÁS': (time(8, 0), ['u-nicolas']),
      'pon una alarma manana a las 8 para nicolas': (time(8, 0), ['u-nicolas']),
      'Ponle una alarma a Pedro mañana a las 7': (time(7, 0), ['u-pedro']),
    };
    cases.forEach((text, expected) {
      test(text, () {
        final r = interpret(text);
        expect(r.draft.intent, CommandIntent.createAlarm, reason: text);
        expect(r.draft.time, expected.$1, reason: text);
        expect(recipientIds(r), ['u-me', ...expected.$2], reason: text);
      });
    });

    test('múltiples destinatarios con comas', () {
      final r = interpret('Pon una alarma mañana a las 7 para Nicolás, Juan y María');
      expect(recipientIds(r), ['u-me', 'u-nicolas', 'u-juan', 'u-maria']);
    });

    test('destinatarios con "con" (dictado por voz)', () {
      final r = interpret('Establece una alarma a las 4:00 pm con Nicolás, Juan y María');
      expect(r.draft.time, LocalTime(16, 0));
      expect(recipientIds(r), ['u-me', 'u-nicolas', 'u-juan', 'u-maria']);
      expect(r.confirmation?.partial, isFalse);
    });

    test('nombres sin comas: "Nicolás Juan y María"', () {
      final r = interpret('alarma a las 4 pm para nicolas juan y maria');
      expect(recipientIds(r), ['u-me', 'u-nicolas', 'u-juan', 'u-maria']);
    });

    test('nombre completo seguido de otro sin coma', () {
      final r = interpret('alarma a las 4 pm con Juan Pérez María');
      expect(recipientIds(r), ['u-me', 'u-juan', 'u-maria']);
    });

    test('"con" que no es una persona queda como mensaje', () {
      final r = interpret('Pon una alarma a las 5 pm con sonido suave');
      expect(recipientIds(r), ['u-me']);
      expect(r.draft.message, 'Con sonido suave');
    });

    test('"todo el equipo" se resuelve como grupo', () {
      final r = interpret('Programa una alarma para todo el equipo a las 9 mañana');
      expect(recipientIds(r), ['u-me', 'g-dev']);
    });

    test('grupo por nombre con artículo: "para la familia"', () {
      final r = interpret('Pon una alarma mañana a las 9 para la familia');
      expect(recipientIds(r), ['u-me', 'g-family']);
    });

    test('sin destinatario: alarma personal', () {
      final r = interpret('Pon una alarma mañana a las 6:30 am');
      expect(r.draft.recipients.single.type, ResolvedRecipientType.self);
      expect(r.confirmation!.lines.map((l) => l.text), contains('Tú'));
    });

    test('"recuérdame" incluye al usuario', () {
      final r = interpret('Recuérdame mañana a las 4 de la tarde tomar la pastilla');
      expect(r.draft.recipients.single.type, ResolvedRecipientType.self);
      expect(r.draft.message, 'Tomar la pastilla');
      expect(r.draft.time, time(16, 0));
    });

    test('"para despertar" es el motivo, no una persona', () {
      final r = interpret('Pon una alarma mañana para despertar a las 7');
      expect(r.draft.message, 'Despertar');
      expect(r.draft.recipients.single.type, ResolvedRecipientType.self);
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('recordatorio con "que": mensaje y destinatario', () {
      final r = interpret('Recuérdale a Juan que llame al médico mañana a las 4');
      expect(recipientIds(r), ['u-me', 'u-juan']);
      expect(r.draft.message, 'Llame al médico');
      expect(r.draft.time, time(16, 0));
      expect(r.draft.date, date(2026, 10, 4));
    });

    test('mensaje sin comillas seguido de fecha y hora', () {
      final r = interpret('Crea una alarma que diga reunión mañana a las 8');
      expect(r.draft.message, 'Reunión');
      expect(r.draft.date, date(2026, 10, 4));
      expect(r.draft.time, time(8, 0));
    });

    test('relativa: "en 10 minutos"', () {
      final r = interpret('Pon una alarma en 10 minutos');
      expect(r.draft.date, date(2026, 10, 3));
      expect(r.draft.time, time(10, 10));
    });

    test('"dentro de una hora y media"', () {
      final r = interpret('Avísame dentro de una hora y media');
      expect(r.draft.time, time(11, 30));
    });
  });

  group('Usuarios ambiguos o inexistentes', () {
    test('varios Carlos: no elige arbitrariamente', () {
      final r = interpret('Crea una alarma mañana a las 8 para Carlos');
      expect(r.status, InterpretationStatus.needsClarification);
      final q = r.pendingClarification!;
      expect(q.kind, ClarificationKind.recipientAmbiguous);
      expect(q.question, contains('varios usuarios llamados Carlos'));
      expect(q.options.map((o) => o.label),
          ['Carlos Pérez', 'Carlos Torres', 'Carlos Gómez']);
    });

    test('elegir una opción completa el borrador', () {
      final r = interpret('Crea una alarma mañana a las 8 para Carlos');
      final next = interpreter.applyOptionSync(
        r.draft,
        r.pendingClarification!.options[1],
        context(),
      );
      expect(next.status, InterpretationStatus.needsConfirmation);
      expect(recipientIds(next), ['u-me', 'u-carlos-t']);
    });

    test('responder escribiendo el apellido', () {
      final r = interpret('Crea una alarma mañana a las 8 para Carlos');
      final next = interpreter.answerSync(r, 'Carlos Gómez', context());
      expect(recipientIds(next), ['u-me', 'u-carlos-g']);
    });

    test('responder "el primero"', () {
      final r = interpret('Crea una alarma mañana a las 8 para Carlos');
      final next = interpreter.answerSync(r, 'el primero', context());
      expect(recipientIds(next), ['u-me', 'u-carlos-p']);
    });

    test('nombre completo resuelve directamente', () {
      final r = interpret('Crea una alarma mañana a las 8 para Carlos Torres');
      expect(recipientIds(r), ['u-me', 'u-carlos-t']);
    });

    test('usuario inexistente ofrece buscar, invitar o cancelar', () {
      final r = interpret('Crea una alarma mañana a las 8 para Roberto');
      final q = r.pendingClarification!;
      expect(q.kind, ClarificationKind.recipientNotFound);
      expect(q.question, 'No encontré a "Roberto" entre tus contactos.');
      expect(q.options.map((o) => o.action), [
        OptionAction.searchUsers,
        OptionAction.inviteUser,
        OptionAction.cancel,
      ]);
      expect(q.options[1].label, 'Invitar a Roberto');
    });

    test('nombre mal escrito sugiere el contacto parecido', () {
      final r = interpret('Crea una alarma mañana a las 8 para Pedor');
      final q = r.pendingClarification!;
      expect(q.question, contains('¿Quisiste decir Pedro?'));
      expect(q.options.first.label, 'Pedro');
    });

    test('grupo genérico sin grupos que coincidan', () {
      final r = interpret(
        'Pon una alarma mañana a las 9 para el equipo',
        ctx: context(groupList: const []),
      );
      expect(r.pendingClarification!.kind, ClarificationKind.groupNotFound);
    });
  });

  group('Confirmación', () {
    test('el resumen contiene hora, fecha y destinatario', () {
      final r = interpret('Crea una alarma mañana a las 8 para Nicolás');
      final summary = r.confirmation!;
      expect(summary.title, 'Nueva alarma');
      expect(summary.question, '¿Quieres crearla?');
      expect(summary.toPlainText(), contains('⏰ 08:00 AM'));
      expect(summary.toPlainText(), contains('📅 Mañana'));
      expect(summary.toPlainText(), contains('👤 Nicolás'));
      expect(summary.partial, isFalse);
    });

    test('comprensión parcial ofrece Editar/Confirmar', () {
      final r = interpret('Crea una alarma zzz mañana qwerty a las 8 para Nicolás');
      final summary = r.confirmation!;
      expect(summary.partial, isTrue);
      expect(summary.cancelLabel, 'Editar');
      expect(summary.toPlainText(), startsWith('No entendí completamente la instrucción.'));
    });

    test('sin verbo explícito también pide confirmar como parcial', () {
      final r = interpret('Todos los días a las 7 para Nicolás');
      expect(r.status, InterpretationStatus.needsConfirmation);
      expect(r.draft.repeat!.frequency, RepeatFrequency.daily);
    });
  });

  group('Serialización', () {
    test('el resultado se puede guardar y restaurar', () {
      final r = interpret('Crea una alarma mañana a las 8 para Carlos que diga "Hola"');
      final restored = InterpretationResult.fromJson(r.toJson());
      expect(restored.status, r.status);
      expect(restored.draft.unresolvedRecipients, ['Carlos']);
      expect(restored.draft.message, 'Hola');
      expect(restored.pendingClarification!.options.length, 3);
      final next = interpreter.applyOptionSync(
        restored.draft,
        restored.pendingClarification!.options.first,
        context(),
      );
      expect(recipientIds(next), ['u-me', 'u-carlos-p']);
    });

    test('el JSON del borrador tiene el formato de la API', () {
      final r = interpret('Crea una alarma mañana a las 8 para Nicolás que diga "Reunión"');
      final json = r.draft.toJson();
      expect(json['action'], 'create_alarm');
      expect(json['date'], '2026-10-04');
      expect(json['time'], '08:00');
      expect(json['message'], 'Reunión');
      final recipients = json['recipients'] as List<Map<String, dynamic>>;
      expect(recipients.map((x) => x['display_name']), ['Tú', 'Nicolás']);
    });
  });
}
