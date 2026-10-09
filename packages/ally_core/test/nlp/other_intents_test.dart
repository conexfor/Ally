import 'package:ally_core/ally_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

final _alarms = [
  AlarmCandidate(
    alarmId: 'a-3pm',
    title: 'Reunión',
    time: time(15, 0),
    nextOccurrence: LocalDateTime(date(2026, 10, 3), time(15, 0)),
  ),
  AlarmCandidate(
    alarmId: 'a-5pm',
    title: 'Entrenamiento',
    time: time(17, 0),
    nextOccurrence: LocalDateTime(date(2026, 10, 3), time(17, 0)),
  ),
  AlarmCandidate(
    alarmId: 'a-8am',
    title: 'Despertar',
    time: time(8, 0),
    nextOccurrence: LocalDateTime(date(2026, 10, 4), time(8, 0)),
  ),
  AlarmCandidate(
    alarmId: 'a-8am-mon',
    title: 'Clase',
    time: time(8, 0),
    nextOccurrence: LocalDateTime(date(2026, 10, 5), time(8, 0)),
  ),
  AlarmCandidate(
    alarmId: 'a-received',
    title: 'De Juan',
    time: time(9, 0),
    nextOccurrence: LocalDateTime(date(2026, 10, 4), time(9, 0)),
    isOwn: false,
    isRinging: true,
  ),
];

InterpretationContext _ctx() => context(alarms: _alarms);

void main() {
  group('Detección de intents', () {
    final cases = <String, CommandIntent>{
      'Crea una alarma a las 8': CommandIntent.createAlarm,
      'Quiero una alarma a las 8': CommandIntent.createAlarm,
      'Configura una alarma para mañana a las 9': CommandIntent.createAlarm,
      'Establece una alarma a las 7': CommandIntent.createAlarm,
      '¿Puedes ponerme una alarma a las 7?': CommandIntent.createAlarm,
      'Cambia la alarma de las 8 a las 9': CommandIntent.editAlarm,
      'Mueve la alarma de mañana al lunes': CommandIntent.editAlarm,
      'Cancela la alarma de las 3': CommandIntent.deleteAlarm,
      'Elimina la alarma de mañana': CommandIntent.deleteAlarm,
      'Borra la alarma de las 5': CommandIntent.deleteAlarm,
      'Desactiva la alarma de mañana': CommandIntent.cancelAlarm,
      'Apaga la alarma': CommandIntent.cancelAlarm,
      '¿Qué alarmas tengo mañana?': CommandIntent.listAlarms,
      'Muéstrame mis alarmas': CommandIntent.listAlarms,
      '¿Tengo alarmas hoy?': CommandIntent.listAlarms,
      'Posponer 10 minutos': CommandIntent.snoozeAlarm,
      'Pospón la alarma 5 minutos': CommandIntent.snoozeAlarm,
      'Dame 10 minutos más': CommandIntent.snoozeAlarm,
      'Crea un grupo llamado Familia': CommandIntent.createGroup,
      'Nuevo grupo Universidad': CommandIntent.createGroup,
      'Agrega a Juan al grupo Familia': CommandIntent.addMember,
      'Añade a María al equipo': CommandIntent.addMember,
      'Saca a Pedro del grupo Familia': CommandIntent.removeMember,
      'Elimina a Juan del grupo Universidad': CommandIntent.removeMember,
      'Muéstrame mis contactos': CommandIntent.listContacts,
      '¿Quiénes son mis contactos?': CommandIntent.listContacts,
      '¿Qué grupos tengo?': CommandIntent.listGroups,
      'Mis grupos': CommandIntent.listGroups,
      'Ayuda': CommandIntent.help,
      '¿Qué puedes hacer?': CommandIntent.help,
      'Hola': CommandIntent.help,
      'El cielo es azul': CommandIntent.unknown,
      'Pon una alarma para cancelar la suscripción a las 8': CommandIntent.createAlarm,
    };
    final parser = NaturalLanguageAlarmParser();
    cases.forEach((text, intent) {
      test('"$text" → ${intent.code}', () {
        expect(parser.parse(text).intent, intent, reason: text);
      });
    });
  });

  group('LIST_ALARMS', () {
    test('"¿Qué alarmas tengo mañana?" → filtro mañana', () {
      final r = interpret('¿Qué alarmas tengo mañana?');
      expect(r.draft.intent, CommandIntent.listAlarms);
      expect(r.draft.date, date(2026, 10, 4));
      expect(r.status, InterpretationStatus.readyToExecute);
    });

    test('"las alarmas de la tarde" → franja', () {
      final r = interpret('Muéstrame las alarmas de la tarde');
      expect(r.draft.period, DayPeriod.afternoon);
    });
  });

  group('DELETE_ALARM / CANCEL_ALARM', () {
    test('"Cancela la alarma de las 5" → 17:00 (única coincidencia)', () {
      final r = interpret('Cancela la alarma de las 5', ctx: _ctx());
      expect(r.draft.intent, CommandIntent.deleteAlarm);
      expect(r.draft.target!.times, [time(17, 0), time(5, 0)]);
      expect(r.draft.target!.alarmId, 'a-5pm');
      expect(r.status, InterpretationStatus.needsConfirmation);
      expect(r.confirmation!.destructive, isTrue);
    });

    test('"Cancela la alarma de las 3" → 15:00', () {
      final r = interpret('Cancela la alarma de las 3', ctx: _ctx());
      expect(r.draft.target!.alarmId, 'a-3pm');
    });

    test('varias coincidencias: pregunta cuál', () {
      final r = interpret('Elimina la alarma de las 8', ctx: _ctx());
      final q = r.pendingClarification!;
      expect(q.kind, ClarificationKind.alarmAmbiguous);
      expect(q.options.map((o) => o.id), ['a-8am', 'a-8am-mon']);
      final next = interpreter.applyOptionSync(r.draft, q.options[1], _ctx());
      expect(next.draft.target!.alarmId, 'a-8am-mon');
      expect(next.status, InterpretationStatus.needsConfirmation);
    });

    test('fecha + hora desambiguan', () {
      final r = interpret('Elimina la alarma de mañana a las 8', ctx: _ctx());
      expect(r.draft.target!.alarmId, 'a-8am');
    });

    test('sin coincidencias: mensaje claro', () {
      final r = interpret('Cancela la alarma de las 11 pm', ctx: _ctx());
      expect(r.status, InterpretationStatus.invalid);
      expect(r.reply, 'No encontré ninguna alarma a las 11:00 PM.');
    });

    test('no se pueden eliminar alarmas de otros', () {
      final r = interpret('Elimina la alarma de las 9', ctx: _ctx());
      expect(r.status, InterpretationStatus.invalid);
    });
  });

  group('EDIT_ALARM', () {
    test('"Cambia la alarma de las 8 de mañana a las 9"', () {
      final r = interpret('Cambia la alarma de mañana de las 8 a las 9', ctx: _ctx());
      expect(r.draft.intent, CommandIntent.editAlarm);
      expect(r.draft.target!.alarmId, 'a-8am');
      expect(r.draft.time, time(9, 0));
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('conserva AM/PM de la alarma original', () {
      final r = interpret('Cambia la alarma de las 5 a las 6', ctx: _ctx());
      expect(r.draft.target!.alarmId, 'a-5pm');
      expect(r.draft.time, time(18, 0));
    });

    test('sin cambios: pide qué cambiar', () {
      final r = interpret('Modifica la alarma de las 3', ctx: _ctx());
      expect(r.status, InterpretationStatus.invalid);
      expect(r.reply, startsWith('Dime qué quieres cambiar'));
    });
  });

  group('SNOOZE_ALARM', () {
    test('"Posponer 10 minutos" usa la alarma que está sonando', () {
      final r = interpret('Posponer 10 minutos', ctx: _ctx());
      expect(r.draft.snoozeMinutes, 10);
      expect(r.draft.target!.alarmId, 'a-received');
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('"media hora"', () {
      expect(interpret('Pospón la alarma media hora', ctx: _ctx()).draft.snoozeMinutes, 30);
    });

    test('sin duración ofrece 5/10/15/30 y personalizado', () {
      final r = interpret('Pospón la alarma', ctx: _ctx());
      final q = r.pendingClarification!;
      expect(q.kind, ClarificationKind.snoozeDuration);
      expect(q.options.map((o) => o.label), ['5 minutos', '10 minutos', '15 minutos', '30 minutos']);
      expect(q.allowsFreeText, isTrue);
      final next = interpreter.answerSync(r, '20', _ctx());
      expect(next.draft.snoozeMinutes, 20);
    });
  });

  group('Grupos', () {
    test('crear grupo con miembros', () {
      final r = interpret('Crea un grupo llamado Amigos con Juan y María');
      expect(r.draft.intent, CommandIntent.createGroup);
      expect(r.draft.groupName, 'Amigos');
      expect([for (final m in r.draft.members) m.id], ['u-juan', 'u-maria']);
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('crear grupo sin nombre pregunta el nombre', () {
      final r = interpret('Crea un grupo');
      expect(r.pendingClarification!.kind, ClarificationKind.missingGroupName);
      final next = interpreter.answerSync(r, 'Gimnasio', context());
      expect(next.draft.groupName, 'Gimnasio');
      expect(next.status, InterpretationStatus.needsConfirmation);
    });

    test('agregar miembro a grupo existente', () {
      final r = interpret('Agrega a Pedro al grupo Familia');
      expect(r.draft.groupId, 'g-family');
      expect(r.draft.members.single.id, 'u-pedro');
      expect(r.status, InterpretationStatus.needsConfirmation);
    });

    test('"al equipo" resuelve "Equipo Desarrollo"', () {
      final r = interpret('Añade a María al equipo');
      expect(r.draft.groupId, 'g-dev');
    });

    test('quitar miembro (destructivo)', () {
      final r = interpret('Saca a Juan del equipo Desarrollo');
      expect(r.draft.intent, CommandIntent.removeMember);
      expect(r.draft.groupId, 'g-dev');
      expect(r.confirmation!.destructive, isTrue);
    });

    test('grupo inexistente', () {
      final r = interpret('Agrega a Pedro al grupo Ajedrez');
      expect(r.pendingClarification!.kind, ClarificationKind.groupNotFound);
    });
  });

  group('Ayuda y no entendido', () {
    test('ayuda devuelve ejemplos', () {
      final r = interpret('ayuda');
      expect(r.status, InterpretationStatus.readyToExecute);
      expect(r.reply, contains('Crea una alarma mañana a las 8 para Juan'));
    });

    test('texto sin sentido', () {
      final r = interpret('asdf qwer');
      expect(r.status, InterpretationStatus.notUnderstood);
      expect(r.reply, startsWith('No entendí la instrucción.'));
    });

    test('texto vacío', () {
      expect(interpret('   ').status, InterpretationStatus.notUnderstood);
    });

    test('nunca lanza excepciones con entradas extrañas', () {
      for (final text in [
        '|||', '@@@', '"', '"""', 'a las', 'para', 'para y y y', '99:99',
        'el 45 de octubre', '😀 alarma 😀 a las 8', 'a las 25', 'cada 0 días',
        'recuérdame', 'que diga', 'Crea una alarma que diga ""',
      ]) {
        expect(() => interpret(text), returnsNormally, reason: text);
      }
    });
  });

  group('Respuestas de confirmación', () {
    const parser = ConfirmationReplyParser();
    test('afirmativas', () {
      for (final t in ['sí', 'Si', 'dale', 'Confirmar', 'ok', 'vale', 'claro', 'Sí, por favor']) {
        expect(parser.parse(t), ConfirmationReply.confirm, reason: t);
      }
    });
    test('negativas', () {
      for (final t in ['no', 'Cancelar', 'mejor no', 'olvídalo']) {
        expect(parser.parse(t), ConfirmationReply.reject, reason: t);
      }
    });
    test('otras', () {
      expect(parser.parse('a las 9'), ConfirmationReply.unknown);
    });
  });
}
