import 'package:ally_core/ally_core.dart';
import 'package:test/test.dart';

void main() {
  test('Bogotá es UTC-5', () {
    final utc = ZonedSchedule.toUtc(
      LocalDateTime(LocalDate(2026, 10, 4), LocalTime(8, 0)),
      'America/Bogota',
    );
    expect(utc, DateTime.utc(2026, 10, 4, 13, 0));
    expect(ZonedSchedule.toLocal(utc, 'America/Bogota').time, LocalTime(8, 0));
  });

  test('una alarma diaria conserva la hora local tras el cambio de horario', () {
    final start = LocalDateTime(LocalDate(2026, 10, 24), LocalTime(8, 0));
    final list = ZonedSchedule.occurrencesBetweenUtc(
      start: start,
      rule: RepeatRule.daily(),
      timezone: 'Europe/Madrid',
      fromUtc: DateTime.utc(2026, 10, 24),
      untilUtc: DateTime.utc(2026, 10, 27),
    );
    // 24 y 25 de octubre: CEST (UTC+2) hasta el 25 a las 03:00 → CET (UTC+1).
    expect(list, [
      DateTime.utc(2026, 10, 24, 6, 0),
      DateTime.utc(2026, 10, 25, 7, 0),
      DateTime.utc(2026, 10, 26, 7, 0),
    ]);
  });

  test('zona horaria inválida', () {
    expect(ZonedSchedule.isValidTimezone('Mars/Olympus'), isFalse);
    expect(ZonedSchedule.isValidTimezone('America/Mexico_City'), isTrue);
  });

  test('códigos de invitación', () {
    expect(InvitationCode.parsePayload('ally://connect?code=ab12cd34'), 'AB12CD34');
    expect(InvitationCode.parsePayload('ab12-cd34'), 'AB12CD34');
    expect(InvitationCode.parsePayload('hola'), isNull);
  });

  test('validadores', () {
    expect(Validators.username('@Nicolas'), isNull);
    expect(Validators.username('ab'), isNotNull);
    expect(Validators.password('abc12345'), isNull);
    expect(Validators.password('abcdefgh'), isNotNull);
    expect(Validators.email('a@b.co'), isNull);
    expect(Validators.email('a@b'), isNotNull);
  });
}
