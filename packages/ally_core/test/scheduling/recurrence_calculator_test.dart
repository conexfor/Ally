import 'package:ally_core/ally_core.dart';
import 'package:test/test.dart';

LocalDateTime dt(int y, int mo, int d, int h, int mi) =>
    LocalDateTime(LocalDate(y, mo, d), LocalTime(h, mi));

void main() {
  const calc = RecurrenceCalculator();

  group('Sin repetición', () {
    test('devuelve la fecha si es futura', () {
      expect(
        calc.nextOccurrence(start: dt(2026, 10, 4, 8, 0), rule: null, after: dt(2026, 10, 3, 10, 0)),
        dt(2026, 10, 4, 8, 0),
      );
    });
    test('null si ya pasó', () {
      expect(
        calc.nextOccurrence(start: dt(2026, 10, 2, 8, 0), rule: null, after: dt(2026, 10, 3, 10, 0)),
        isNull,
      );
    });
  });

  group('Diaria', () {
    test('siguiente día a la misma hora', () {
      expect(
        calc.nextOccurrence(
          start: dt(2026, 10, 1, 8, 0),
          rule: RepeatRule.daily(),
          after: dt(2026, 10, 3, 10, 0),
        ),
        dt(2026, 10, 4, 8, 0),
      );
    });
    test('cada 3 días respeta el ancla', () {
      expect(
        calc.nextOccurrence(
          start: dt(2026, 10, 1, 8, 0),
          rule: RepeatRule.daily(interval: 3),
          after: dt(2026, 10, 3, 10, 0),
        ),
        dt(2026, 10, 4, 8, 0),
      );
      expect(
        calc.nextOccurrence(
          start: dt(2026, 10, 1, 8, 0),
          rule: RepeatRule.daily(interval: 3),
          after: dt(2026, 10, 4, 8, 0),
        ),
        dt(2026, 10, 7, 8, 0),
      );
    });
    test('cruza fin de mes y de año', () {
      expect(
        calc.nextOccurrence(
          start: dt(2026, 12, 30, 23, 0),
          rule: RepeatRule.daily(),
          after: dt(2026, 12, 31, 23, 30),
        ),
        dt(2027, 1, 1, 23, 0),
      );
    });
  });

  group('Semanal', () {
    final monWed = RepeatRule.weekly({DateTime.monday, DateTime.wednesday});
    test('lunes y miércoles desde un sábado', () {
      expect(
        calc.nextOccurrence(start: dt(2026, 10, 3, 7, 0), rule: monWed, after: dt(2026, 10, 3, 10, 0)),
        dt(2026, 10, 5, 7, 0),
      );
    });
    test('ocurrencias de una semana', () {
      final list = calc.occurrencesBetween(
        start: dt(2026, 10, 3, 7, 0),
        rule: monWed,
        from: dt(2026, 10, 3, 0, 0),
        to: dt(2026, 10, 17, 0, 0),
      );
      expect(list, [
        dt(2026, 10, 5, 7, 0),
        dt(2026, 10, 7, 7, 0),
        dt(2026, 10, 12, 7, 0),
        dt(2026, 10, 14, 7, 0),
      ]);
    });
    test('cada 2 semanas', () {
      final rule = RepeatRule.weekly({DateTime.monday}, interval: 2);
      final list = calc.occurrencesBetween(
        start: dt(2026, 10, 5, 9, 0),
        rule: rule,
        from: dt(2026, 10, 1, 0, 0),
        to: dt(2026, 11, 3, 0, 0),
      );
      expect(list, [dt(2026, 10, 5, 9, 0), dt(2026, 10, 19, 9, 0), dt(2026, 11, 2, 9, 0)]);
    });
  });

  group('Mensual', () {
    test('día 31 en meses cortos usa el último día', () {
      final rule = RepeatRule(frequency: RepeatFrequency.monthly, dayOfMonth: 31);
      final list = calc.occurrencesBetween(
        start: dt(2027, 1, 31, 9, 0),
        rule: rule,
        from: dt(2027, 1, 1, 0, 0),
        to: dt(2027, 5, 1, 0, 0),
      );
      expect(list, [
        dt(2027, 1, 31, 9, 0),
        dt(2027, 2, 28, 9, 0),
        dt(2027, 3, 31, 9, 0),
        dt(2027, 4, 30, 9, 0),
      ]);
    });
  });

  test('until limita las ocurrencias', () {
    final rule = RepeatRule(frequency: RepeatFrequency.daily, until: LocalDate(2026, 10, 5));
    expect(
      calc.nextOccurrence(start: dt(2026, 10, 1, 8, 0), rule: rule, after: dt(2026, 10, 5, 9, 0)),
      isNull,
    );
  });

  group('RepeatRule JSON', () {
    test('ida y vuelta', () {
      final rule = RepeatRule.weekly({1, 3});
      expect(rule.toJson(), {
        'repeat': true,
        'frequency': 'weekly',
        'interval': 1,
        'days': ['monday', 'wednesday'],
      });
      expect(RepeatRule.fromJson(rule.toJson()), rule);
    });
    test('semanal sin días es inválida', () {
      expect(() => RepeatRule.weekly({}), throwsArgumentError);
    });
  });

  group('LocalDate', () {
    test('nextWeekday', () {
      final saturday = LocalDate(2026, 10, 3);
      expect(saturday.nextWeekday(DateTime.saturday), saturday);
      expect(saturday.nextWeekday(DateTime.saturday, includeToday: false), LocalDate(2026, 10, 10));
      expect(saturday.nextWeekday(DateTime.monday), LocalDate(2026, 10, 5));
    });
    test('años bisiestos', () {
      expect(LocalDate.isValid(2028, 2, 29), isTrue);
      expect(LocalDate.isValid(2027, 2, 29), isFalse);
      expect(LocalDate.isValid(2100, 2, 29), isFalse);
    });
    test('formato 12 h', () {
      expect(LocalTime(0, 5).format12h(), '12:05 AM');
      expect(LocalTime(12, 0).format12h(), '12:00 PM');
      expect(LocalTime(14, 30).format12h(), '2:30 PM');
    });
  });
}
