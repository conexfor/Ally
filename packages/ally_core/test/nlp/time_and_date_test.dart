import 'package:ally_core/ally_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('Formatos de hora (fecha explícita: mañana)', () {
    final cases = <String, LocalTime>{
      '8': time(8, 0),
      '8:00': time(8, 0),
      '08:00': time(8, 0),
      '8 am': time(8, 0),
      '8 a.m.': time(8, 0),
      '8 a. m.': time(8, 0),
      '8 de la mañana': time(8, 0),
      '8 pm': time(20, 0),
      '8 p.m.': time(20, 0),
      '8 de la noche': time(20, 0),
      '14:30': time(14, 30),
      '2:30 pm': time(14, 30),
      '2 y media de la tarde': time(14, 30),
      '8 y cuarto': time(8, 15),
      '8 menos cuarto': time(7, 45),
      'ocho y media': time(8, 30),
      'las ocho de la noche': time(20, 0),
      '7.30': time(7, 30),
      '20h': time(20, 0),
      '12 del mediodía': time(12, 0),
      'mediodía': time(12, 0),
      '1 de la madrugada': time(1, 0),
      '00:15': time(0, 15),
    };
    cases.forEach((spoken, expected) {
      test('"$spoken" → $expected', () {
        final r = interpret('Pon una alarma mañana a las $spoken');
        expect(r.draft.time, expected, reason: spoken);
        expect(r.draft.date, date(2026, 10, 4), reason: spoken);
      });
    });

    test('"medianoche"', () {
      final r = interpret('Pon una alarma mañana a medianoche');
      expect(r.draft.time, time(0, 0));
    });
  });

  group('Ambigüedad AM/PM', () {
    test('"a las 12:06" dicho a las 00:05 → 00:06, no el mediodía', () {
      final r = interpret('alarma a las 12:06', ctx: context(now: DateTime(2026, 10, 4, 0, 5)));
      expect(r.draft.time, time(0, 6));
      expect(r.draft.date, LocalDate(2026, 10, 4));
    });

    test('"a las 12:10" dicho a las 23:30 → 00:10 de mañana', () {
      final r = interpret('alarma a las 12:10', ctx: context(now: DateTime(2026, 10, 3, 23, 30)));
      expect(r.draft.time, time(0, 10));
      expect(r.draft.date, LocalDate(2026, 10, 4));
    });

    test('"a las 7" dicho a las 18:30 → hoy 19:00 (inminente)', () {
      final r = interpret('alarma a las 7', ctx: context(now: DateTime(2026, 10, 3, 18, 30)));
      expect(r.draft.time, time(19, 0));
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('"a las 8" sin fecha a las 10:00 pregunta (hoy 20:00 o mañana 08:00)', () {
      final r = interpret('Pon una alarma a las 8');
      expect(r.status, InterpretationStatus.needsClarification);
      final q = r.pendingClarification!;
      expect(q.kind, ClarificationKind.meridiem);
      expect(q.question, '¿Quieres programarla a las 8:00 PM (hoy) o a las 8:00 AM (mañana)?');
      expect(q.options.map((o) => o.label), ['8:00 PM (hoy)', '8:00 AM (mañana)']);
    });

    test('"a las 8" sin fecha a las 06:00 → hoy 08:00 (contexto)', () {
      final r = interpret(
        'Pon una alarma a las 8',
        ctx: context(now: DateTime(2026, 10, 3, 6, 0)),
      );
      expect(r.draft.time, time(8, 0));
      expect(r.draft.date, date(2026, 10, 3));
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('"hoy a las 8" a las 10:00 → 20:00 (única opción futura)', () {
      final r = interpret('Pon una alarma hoy a las 8');
      expect(r.draft.time, time(20, 0));
    });

    test('"mañana a las 6" pregunta: 6 no tiene uso habitual claro', () {
      final r = interpret('Pon una alarma mañana a las 6');
      expect(r.pendingClarification!.kind, ClarificationKind.meridiem);
      expect(r.pendingClarification!.question, '¿Quieres programarla a las 6:00 AM o a las 6:00 PM?');
    });

    test('"mañana a las 5" → 17:00 (uso habitual)', () {
      expect(interpret('Pon una alarma mañana a las 5').draft.time, time(17, 0));
    });

    test('la franja resuelve la ambigüedad: "mañana por la tarde a las 6"', () {
      final r = interpret('Pon una alarma mañana por la tarde a las 6');
      expect(r.draft.time, time(18, 0));
    });

    test('"todas las mañanas a las 6" → 06:00', () {
      final r = interpret('Pon una alarma todas las mañanas a las 6');
      expect(r.draft.time, time(6, 0));
      expect(r.draft.repeat!.frequency, RepeatFrequency.daily);
    });

    test('responder "PM" a la pregunta', () {
      final r = interpret('Pon una alarma mañana a las 6');
      final next = interpreter.answerSync(r, 'pm', context());
      expect(next.draft.time, time(18, 0));
      expect(next.draft.date, date(2026, 10, 4));
      expect(next.status, InterpretationStatus.needsConfirmation);
    });

    test('responder "de la mañana"', () {
      final r = interpret('Pon una alarma a las 8');
      final next = interpreter.answerSync(r, 'de la mañana', context());
      expect(next.draft.time, time(8, 0));
      expect(next.draft.date, date(2026, 10, 4));
    });

    test('elegir la opción "8:00 PM (hoy)"', () {
      final r = interpret('Pon una alarma a las 8');
      final next = interpreter.applyOptionSync(
        r.draft,
        r.pendingClarification!.options.first,
        context(),
      );
      expect(next.draft.scheduledAt, LocalDateTime(date(2026, 10, 3), time(20, 0)));
    });
  });

  group('Hora ausente o pasada', () {
    test('sin hora pregunta "¿A qué hora...?"', () {
      final r = interpret('Crea una alarma mañana para Juan');
      expect(r.pendingClarification!.kind, ClarificationKind.missingTime);
      final next = interpreter.answerSync(r, 'a las 7:30 am', context());
      expect(next.draft.time, time(7, 30));
      expect(next.draft.date, date(2026, 10, 4));
      expect(recipientIds(next), ['u-juan']);
    });

    test('hora explícita ya pasada hoy propone mañana', () {
      final r = interpret('Pon una alarma hoy a las 7 am');
      expect(r.pendingClarification!.kind, ClarificationKind.pastDateTime);
      final next = interpreter.applyOptionSync(
        r.draft,
        r.pendingClarification!.options.first,
        context(),
      );
      expect(next.draft.date, date(2026, 10, 4));
      expect(next.status, InterpretationStatus.needsConfirmation);
    });

    test('sin fecha y hora explícita ya pasada → mañana', () {
      final r = interpret('Pon una alarma a las 7 am');
      expect(r.draft.date, date(2026, 10, 4));
      expect(r.draft.dateInferred, isTrue);
    });
  });

  group('Fechas', () {
    final cases = <String, LocalDate>{
      'hoy a las 11 pm': date(2026, 10, 3),
      'mañana a las 9': date(2026, 10, 4),
      'pasado mañana a las 9': date(2026, 10, 5),
      'el lunes a las 9': date(2026, 10, 5),
      'el martes a las 9': date(2026, 10, 6),
      'este miércoles a las 9': date(2026, 10, 7),
      'el próximo lunes a las 9': date(2026, 10, 5),
      'el sábado a las 11 pm': date(2026, 10, 3),
      'el próximo sábado a las 9': date(2026, 10, 10),
      'el sábado que viene a las 9': date(2026, 10, 10),
      'el domingo a las 9': date(2026, 10, 4),
      'el viernes a las 9': date(2026, 10, 9),
      'el 3 de octubre a las 11 pm': date(2026, 10, 3),
      'el 15 de octubre a las 9': date(2026, 10, 15),
      'el 2 de enero a las 9': date(2027, 1, 2),
      'el 3/10 a las 11 pm': date(2026, 10, 3),
      'el 25/12 a las 9': date(2026, 12, 25),
      'el 03/10/2027 a las 9': date(2027, 10, 3),
      'el 2026-10-20 a las 9': date(2026, 10, 20),
      'en 3 días a las 9': date(2026, 10, 6),
      'el viernes 9 de octubre a las 9': date(2026, 10, 9),
    };
    cases.forEach((spoken, expected) {
      test('"$spoken" → $expected', () {
        final r = interpret('Pon una alarma $spoken');
        expect(r.draft.date, expected, reason: spoken);
      });
    });

    test('"esta noche a las 9" → hoy 21:00', () {
      final r = interpret('Pon una alarma esta noche a las 9');
      expect(r.draft.date, date(2026, 10, 3));
      expect(r.draft.time, time(21, 0));
    });

    test('"mañana por la mañana a las 7"', () {
      final r = interpret('Pon una alarma mañana por la mañana a las 7');
      expect(r.draft.date, date(2026, 10, 4));
      expect(r.draft.time, time(7, 0));
    });

    test('fecha imposible: 31 de febrero', () {
      final r = interpret('Pon una alarma el 31 de febrero a las 9');
      expect(r.status, InterpretationStatus.invalid);
      expect(r.reply, 'La fecha indicada no existe.');
    });
  });

  group('Recurrencias', () {
    test('todos los días', () {
      final r = interpret('Todos los días a las 8');
      expect(r.draft.repeat, RepeatRule.daily());
      expect(r.draft.date, date(2026, 10, 4)); // 08:00 de hoy ya pasó
    });

    test('todos los lunes', () {
      final r = interpret('Todos los lunes a las 9');
      expect(r.draft.repeat, RepeatRule.weekly({1}));
    });

    test('cada lunes y miércoles a las 7', () {
      final r = interpret('Cada lunes y miércoles a las 7');
      expect(r.draft.repeat, RepeatRule.weekly({1, 3}));
      expect(r.draft.repeat!.toJson()['days'], ['monday', 'wednesday']);
      expect(r.draft.time, time(7, 0));
    });

    test('de lunes a viernes', () {
      final r = interpret('De lunes a viernes a las 8');
      expect(r.draft.repeat, RepeatRule.weekly({1, 2, 3, 4, 5}));
      expect(r.draft.date, date(2026, 10, 5));
    });

    test('fines de semana', () {
      final r = interpret('Pon una alarma los fines de semana a las 10');
      expect(r.draft.repeat, RepeatRule.weekly({6, 7}));
      expect(r.draft.date, date(2026, 10, 4)); // hoy sábado 10:00 ya pasó
    });

    test('cada 2 días', () {
      final r = interpret('Pon una alarma cada 2 días a las 9 pm');
      expect(r.draft.repeat, RepeatRule.daily(interval: 2));
    });

    test('lunes, miércoles y viernes', () {
      final r = interpret('Los lunes, miércoles y viernes a las 6:30 am');
      expect(r.draft.repeat, RepeatRule.weekly({1, 3, 5}));
    });

    test('cada semana el martes', () {
      final r = interpret('Pon una alarma cada semana el martes a las 9');
      expect(r.draft.repeat, RepeatRule.weekly({2}));
      expect(r.draft.date, date(2026, 10, 6));
    });

    test('el 5 de cada mes', () {
      final r = interpret('Pon una alarma el 5 de cada mes a las 9');
      expect(r.draft.repeat!.frequency, RepeatFrequency.monthly);
      expect(r.draft.repeat!.dayOfMonth, 5);
    });

    test('con destinatario', () {
      final r = interpret('Todos los días a las 7 para Nicolás');
      expect(r.draft.repeat, RepeatRule.daily());
      expect(recipientIds(r), ['u-nicolas']);
    });

    test('resumen de la recurrencia', () {
      final r = interpret('Crea una alarma cada lunes y miércoles a las 7');
      expect(r.confirmation!.toPlainText(), contains('🔁 Todos los lunes y miércoles'));
    });
  });
}
