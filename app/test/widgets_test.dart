import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ally/core/theme/app_theme.dart';
import 'package:ally/core/utils/alarm_format.dart';
import 'package:ally/core/widgets/common.dart';
import 'package:ally/core/widgets/moment.dart';
import 'package:ally/features/alarms/widgets/alarm_tile.dart';
import 'package:ally/features/auth/login_screen.dart';
import 'package:ally/features/auth/onboarding_screen.dart';
import 'package:ally/features/profile/response_bar.dart';
import 'package:ally_core/ally_core.dart';

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

Alarm _alarm({List<AlarmRecipient> recipients = const [], String? sequenceName}) {
  final next = DateTime.now().toUtc().add(const Duration(days: 1));
  return Alarm(
    id: 'a1',
    creator: const PublicUser(id: 'u-me', username: 'yo', displayName: 'Yo'),
    title: 'Reunión de proyecto',
    localDate: LocalDate.fromDateTime(next.toLocal()),
    localTime: LocalTime(8, 0),
    timezone: 'UTC',
    scheduledAt: next,
    status: AlarmStatus.scheduled,
    priority: AlarmPriority.urgent,
    recipients: recipients,
    nextOccurrenceAt: next,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    sequenceName: sequenceName,
    sequencePosition: sequenceName == null ? null : 1,
  );
}

AlarmRecipient _recipient(String id, String name, ResponseStatus response) => AlarmRecipient(
  id: 'r-$id',
  recipientType: RecipientType.user,
  recipientId: id,
  userId: id,
  displayName: name,
  permissionStatus: PermissionStatus.accepted,
  responseStatus: response,
);

void main() {
  testWidgets('ResponseBadge muestra el estado con texto (no solo color)', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            ResponseBadge(ResponseStatus.confirmed),
            ResponseBadge(ResponseStatus.snoozed),
            ResponseBadge(ResponseStatus.noResponse, permission: PermissionStatus.pending),
          ],
        ),
      ),
    );
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Pospuesta'), findsOneWidget);
    expect(find.text('Pendiente de aceptar'), findsOneWidget);
  });

  testWidgets('AlarmTile muestra título, prioridad, destinatarios, confirmaciones y rutina', (tester) async {
    final alarm = _alarm(
      sequenceName: 'Mañana',
      recipients: [
        _recipient('u-me', 'Yo', ResponseStatus.confirmed),
        _recipient('u-juan', 'Juan', ResponseStatus.confirmed),
        _recipient('u-maria', 'María', ResponseStatus.noResponse),
      ],
    );
    await tester.pumpWidget(_app(AlarmTile(alarm: alarm, meId: 'u-me')));
    expect(find.text('Reunión de proyecto'), findsOneWidget);
    expect(find.text('Urgente'), findsOneWidget);
    expect(find.textContaining('Tú, Juan y María'), findsOneWidget);
    expect(find.textContaining('2/3 confirmaron'), findsOneWidget);
    expect(find.textContaining('Rutina «Mañana» · paso 2'), findsOneWidget);
  });

  testWidgets('ResponseBar muestra valores y porcentajes', (tester) async {
    await tester.pumpWidget(
      _app(
        const ResponseBar(
          shares: [
            ResponseShare('Confirmadas', 3, Colors.green, Icons.check),
            ResponseShare('Pospuestas', 1, Colors.orange, Icons.snooze),
          ],
        ),
      ),
    );
    expect(find.text('75 %'), findsOneWidget);
    expect(find.text('25 %'), findsOneWidget);
  });

  testWidgets('ResponseBar sin datos muestra un mensaje', (tester) async {
    await tester.pumpWidget(
      _app(const ResponseBar(shares: [ResponseShare('Confirmadas', 0, Colors.green, Icons.check)])),
    );
    expect(find.text('Aún no hay respuestas en este periodo.'), findsOneWidget);
  });

  testWidgets('Login valida los campos vacíos sin llamar al servidor', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: const LoginScreen())));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Escribe tu correo o usuario.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
  });

  testWidgets('EmptyState muestra título, mensaje y acción', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        EmptyState(
          icon: Icons.alarm,
          title: 'Sin alarmas',
          message: 'Crea una',
          action: TextButton(onPressed: () => tapped = true, child: const Text('Crear')),
        ),
      ),
    );
    await tester.tap(find.text('Crear'));
    expect(tapped, isTrue);
    expect(find.text('Sin alarmas'), findsOneWidget);
  });

  test('AlarmFormat.countdown describe el tiempo restante', () {
    final now = DateTime.utc(2026, 10, 3, 8);
    expect(AlarmFormat.countdown(now.add(const Duration(minutes: 135)), now), 'Faltan 2 h 15 min');
    expect(AlarmFormat.countdown(now.add(const Duration(minutes: 9)), now), 'Faltan 9 min');
    expect(AlarmFormat.countdown(now.add(const Duration(days: 2, hours: 3)), now), 'Faltan 2 d 3 h');
    expect(AlarmFormat.countdown(now.subtract(const Duration(minutes: 1)), now), 'Sonando ahora');
  });

  testWidgets('Acceso y registro comparten superficie: cambiar de modo no navega', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nombre'), findsNothing);
    await tester.tap(find.text('Crea tu espacio'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu espacio'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Nombre'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding avanza por las tres ideas', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const OnboardingScreen()),
      ),
    );
    expect(find.text('Crea un momento'), findsOneWidget);
    // Las animaciones de la ilustración se repiten: se avanza por tiempo.
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Hazlo compartido'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Todos a tiempo'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('momentColor deduce la identidad del momento', () {
    expect(momentColor(_alarm(), 'u-me'), AppTheme.cyan);
    expect(
      momentColor(
        _alarm(
          recipients: [
            _recipient('u-me', 'Yo', ResponseStatus.noResponse),
            _recipient('u-ana', 'Ana', ResponseStatus.noResponse),
          ],
        ),
        'u-me',
      ),
      AppTheme.violet,
    );
  });

  test('momentStatus resume las confirmaciones del grupo', () {
    final both = _alarm(
      recipients: [
        _recipient('u-me', 'Yo', ResponseStatus.confirmed),
        _recipient('u-ana', 'Ana', ResponseStatus.confirmed),
      ],
    );
    expect(momentStatus(both, 'u-me').label, 'Ambos confirmaron');
    final partial = _alarm(
      recipients: [
        _recipient('u-me', 'Yo', ResponseStatus.confirmed),
        _recipient('u-ana', 'Ana', ResponseStatus.confirmed),
        _recipient('u-leo', 'Leo', ResponseStatus.noResponse),
      ],
    );
    expect(momentStatus(partial, 'u-me').label, '2 de 3 confirmados');
    expect(awaitingConfirmation(partial, 'u-me'), isTrue);
    expect(awaitingConfirmation(both, 'u-me'), isFalse);
  });

  testWidgets('BigTime muestra la hora en 12 h con sufijo', (tester) async {
    await tester.pumpWidget(_app(const BigTime(hour: 19, minute: 5, size: 40)));
    expect(find.text('07:05'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
  });
}
