import 'package:flutter_test/flutter_test.dart';
import 'package:ally/application/assistant/command_executor.dart';
import 'package:ally_core/ally_core.dart';

void main() {
  test('el borrador del asistente se convierte en los datos de la alarma', () {
    final ctx = InterpretationContext(
      now: DateTime(2026, 10, 3, 10),
      selfUserId: 'u-me',
      contacts: const [DirectoryContact(userId: 'u-juan', username: 'juan', displayName: 'Juan')],
      groups: const [DirectoryGroup(groupId: 'g-dev', name: 'Equipo Desarrollo')],
    );
    final result = RuleBasedCommandInterpreter().interpretSync(
      'Crea una alarma mañana a las 8 para Juan y el equipo que diga "Reunión de proyecto"',
      ctx,
    );
    final input = CommandExecutor.toAlarmInput(result.draft, meId: 'u-me', timezone: 'America/Bogota');
    expect(input.title, 'Reunión de proyecto');
    expect(input.localDate, LocalDate(2026, 10, 4));
    expect(input.localTime, LocalTime(8, 0));
    expect(
      input.recipients.map((r) => '${r.type.wire}:${r.id}'),
      ['user:u-juan', 'group:g-dev'],
    );
  });

  test('alarma personal sin mensaje', () {
    final ctx = InterpretationContext(now: DateTime(2026, 10, 3, 10), selfUserId: 'u-me');
    final result = RuleBasedCommandInterpreter().interpretSync('Despiértame mañana a las 6:30 am', ctx);
    final input = CommandExecutor.toAlarmInput(result.draft, meId: 'u-me', timezone: 'UTC');
    expect(input.title, 'Alarma');
    expect(input.recipients.single.id, 'u-me');
  });
}
