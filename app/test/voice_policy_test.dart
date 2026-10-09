import 'package:flutter_test/flutter_test.dart';
import 'package:ally/application/assistant/voice_policy.dart';
import 'package:ally_core/ally_core.dart';

void main() {
  setUpAll(ZonedSchedule.ensureInitialized);

  final ctx = InterpretationContext(
    now: DateTime(2026, 10, 4, 10, 0),
    timezone: 'America/Bogota',
    selfUserId: 'me',
    selfDisplayName: 'Yo',
    contacts: const [
      DirectoryContact(userId: 'u1', username: 'ana', displayName: 'Ana'),
      DirectoryContact(userId: 'u2', username: 'luis', displayName: 'Luis'),
      DirectoryContact(userId: 'u3', username: 'pedro', displayName: 'Pedro'),
      DirectoryContact(userId: 'c1', username: 'carlosp', displayName: 'Carlos Pérez'),
      DirectoryContact(userId: 'c2', username: 'ctorres', displayName: 'Carlos Torres'),
    ],
    groups: const [],
    alarms: const [],
  );
  final interpreter = RuleBasedCommandInterpreter();

  test('la orden completa se crea sin confirmar y se anuncia', () {
    final r = interpreter.interpretSync('establece una alarma a las 4:00 pm con Ana Luis y Pedro', ctx);
    expect(VoicePolicy.autoExecutes(r), isTrue);
    expect(
      VoicePolicy.created(r, 'Alarma creada ✅\nAna, Luis y Pedro deben aceptarla.'),
      'Listo. Alarma creada, hoy, a las 4 de la tarde, para ti, Ana, Luis y Pedro. '
      'Ana, Luis y Pedro deben aceptarla.',
    );
  });

  test('a la 1 en singular', () {
    final r = interpreter.interpretSync('alarma a la 1 pm para Ana', ctx);
    expect(VoicePolicy.created(r, 'Alarma creada ✅'), contains('a la 1 de la tarde'));
  });

  test('comprensión parcial no se ejecuta sola', () {
    final r = interpreter.interpretSync('alarma a las 5 pm blablabla xyz', ctx);
    if (r.status == InterpretationStatus.needsConfirmation && (r.confirmation?.partial ?? false)) {
      expect(VoicePolicy.autoExecutes(r), isFalse);
    }
  });

  test('las opciones de una aclaración se leen', () {
    final r = interpreter.interpretSync('alarma a las 4 pm para Carlos', ctx);
    expect(r.status, InterpretationStatus.needsClarification);
    final speech = VoicePolicy.speech(r);
    expect(speech, contains('Carlos Pérez'));
    expect(speech, contains('Carlos Torres'));
  });

  group('hora que acaba de pasar', () {
    final noche = InterpretationContext(
      now: DateTime(2026, 10, 4, 23, 13, 24),
      timezone: 'America/Lima',
      selfUserId: 'me',
      selfDisplayName: 'Yo',
      contacts: const [],
      groups: const [],
      alarms: const [],
    );
    final ahora = DateTime(2026, 10, 4, 23, 13, 24);

    test('«a las 11:13» dicho a las 23:13 pregunta antes de ponerla mañana', () {
      final r = interpreter.interpretSync('alarma a las 11:13 de la noche', noche);
      expect(VoicePolicy.justPassed(r, now: ahora), isTrue);
      expect(VoicePolicy.autoExecutes(r, now: ahora), isFalse);
      expect(VoicePolicy.speech(r, now: ahora), startsWith('Las 11 y 13 de la noche ya pasaron hoy.'));
    });

    test('una hora futura se crea directamente', () {
      final r = interpreter.interpretSync('alarma a las 11:20 de la noche', noche);
      expect(VoicePolicy.autoExecutes(r, now: ahora), isTrue);
    });

    test('«a las 7 de la mañana» dicho de noche es mañana sin preguntar', () {
      final r = interpreter.interpretSync('alarma a las 7 de la mañana', noche);
      expect(VoicePolicy.justPassed(r, now: ahora), isFalse);
      expect(VoicePolicy.autoExecutes(r, now: ahora), isTrue);
    });

    test('si la alarma es solo tuya no dice «para ti»', () {
      final r = interpreter.interpretSync('alarma a las 11:39 de la noche', noche);
      expect(VoicePolicy.created(r, 'Alarma creada ✅'), 'Listo. Alarma creada, hoy, a las 11 y 39 de la noche.');
    });

    test('una hora sola («a las 9:18») se crea directamente', () {
      final manana = InterpretationContext(now: DateTime(2026, 10, 5, 9, 16), timezone: 'America/Lima',
          selfUserId: 'me', selfDisplayName: 'Yo', contacts: const [], groups: const [], alarms: const []);
      final r = interpreter.interpretSync('a las 9:18', manana);
      expect(r.confirmation?.partial, isTrue);
      expect(VoicePolicy.autoExecutes(r, now: DateTime(2026, 10, 5, 9, 16)), isTrue);
      expect(VoicePolicy.created(r, 'Alarma creada ✅'), 'Listo. Alarma creada, hoy, a las 9 y 18 de la mañana.');
    });

    test('si sobra algo que no entendió, pregunta con una frase natural', () {
      final r = interpreter.interpretSync('pon una alarma a las 11:20 de la noche blablá cosas raras', noche);
      if (r.status == InterpretationStatus.needsConfirmation && (r.confirmation?.partial ?? false)) {
        expect(VoicePolicy.autoExecutes(r, now: ahora), isFalse);
        expect(VoicePolicy.speech(r, now: ahora), 'No entendí todo. ¿Quieres una alarma, hoy, a las 11 y 20 de la noche?');
      }
    });

    test('«en 2 minutos» se crea directamente', () {
      final r = interpreter.interpretSync('alarma en 2 minutos', noche);
      expect(VoicePolicy.autoExecutes(r, now: ahora), isTrue);
    });
  });

  test('las 12 se leen como medianoche o mediodía', () {
    expect(VoicePolicy.clean('12:06 AM'), '12 y 6 de la medianoche');
    expect(VoicePolicy.clean('12:00 AM'), '12 de la medianoche');
    expect(VoicePolicy.clean('12:30 PM'), '12 y 30 del mediodía');
    expect(VoicePolicy.clean('01:15 AM'), '1 y 15 de la madrugada');
  });

  test('limpia emojis, viñetas y horas', () {
    expect(VoicePolicy.clean('Pospuesta 10 minutos 😴'), 'Pospuesta 10 minutos');
    expect(
      VoicePolicy.clean('Tienes 2 alarmas hoy:\n• 07:30 AM — Gym\n• 12:00 PM — Comer'),
      'Tienes 2 alarmas hoy: 7 y 30 de la mañana, Gym. 12 del mediodía, Comer',
    );
  });
}
