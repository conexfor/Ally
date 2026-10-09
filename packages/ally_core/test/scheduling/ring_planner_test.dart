import 'package:test/test.dart';
import 'package:ally_core/ally_core.dart';

const me = 'u-me';
const phone = 'd-phone';
const tablet = 'd-tablet';

Alarm alarm({
  String id = 'a1',
  String creator = 'u-other',
  RepeatRule? repeat,
  DateTime? next,
  List<AlarmRecipient>? recipients,
  AlarmStatus status = AlarmStatus.scheduled,
  LocalDate? date,
  LocalTime? time,
}) {
  final localDate = date ?? LocalDate(2026, 10, 4);
  final localTime = time ?? LocalTime(8, 0);
  final start = ZonedSchedule.toUtc(localDate.at(localTime), 'America/Bogota');
  return Alarm(
    id: id,
    creator: PublicUser(id: creator, username: 'x', displayName: 'Creador'),
    title: 'Prueba',
    localDate: localDate,
    localTime: localTime,
    timezone: 'America/Bogota',
    scheduledAt: start,
    repeat: repeat,
    status: status,
    priority: AlarmPriority.normal,
    recipients: recipients ??
        [
          const AlarmRecipient(
            id: 'r1',
            recipientType: RecipientType.user,
            recipientId: me,
            userId: me,
            displayName: 'Yo',
            permissionStatus: PermissionStatus.accepted,
            responseStatus: ResponseStatus.noResponse,
          ),
        ],
    nextOccurrenceAt: next ?? start,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  ZonedSchedule.ensureInitialized();
  const planner = RingPlanner();
  final now = DateTime.utc(2026, 10, 3, 15); // sábado 10:00 en Bogotá

  List<PlannedRing> plan(
    List<Alarm> alarms, {
    List<AlarmResponse> responses = const [],
    String device = phone,
    bool receives = true,
    Map<String, Map<String, bool>> prefs = const {},
  }) =>
      planner.plan(
        alarms: alarms,
        myResponses: responses,
        userId: me,
        deviceId: device,
        deviceReceivesAlarms: receives,
        devicePreferences: prefs,
        now: now,
      );

  test('una alarma aceptada suena una vez en su hora', () {
    final rings = plan([alarm()]);
    expect(rings, hasLength(1));
    expect(rings.single.ringAt, DateTime.utc(2026, 10, 4, 13));
  });

  test('alarma pendiente de aceptar no suena', () {
    final pending = alarm(recipients: [
      const AlarmRecipient(
        id: 'r1',
        recipientType: RecipientType.user,
        recipientId: me,
        userId: me,
        displayName: 'Yo',
        permissionStatus: PermissionStatus.pending,
        responseStatus: ResponseStatus.noResponse,
      ),
    ]);
    expect(plan([pending]), isEmpty);
  });

  test('recurrente: programa las ocurrencias de la próxima semana', () {
    final daily = alarm(repeat: RepeatRule.daily());
    expect(plan([daily]), hasLength(7));
  });

  test('confirmada no vuelve a sonar; pospuesta suena más tarde', () {
    final a = alarm();
    final occurrence = a.nextOccurrenceAt!;
    expect(
      plan([a], responses: [
        AlarmResponse(
          id: 'x',
          alarmId: a.id,
          userId: me,
          occurrenceAt: occurrence,
          response: ResponseStatus.confirmed,
          respondedAt: now,
        ),
      ]),
      isEmpty,
    );
    final snoozedUntil = now.add(const Duration(minutes: 10));
    final rings = plan([a], responses: [
      AlarmResponse(
        id: 'x',
        alarmId: a.id,
        userId: me,
        occurrenceAt: occurrence,
        response: ResponseStatus.snoozed,
        snoozedUntil: snoozedUntil,
        respondedAt: now,
      ),
    ]);
    expect(rings.single.ringAt, snoozedUntil);
    expect(rings.single.occurrenceAt, occurrence);
  });

  test('respeta la preferencia por dispositivo', () {
    final a = alarm();
    expect(plan([a], prefs: {'a1': {phone: false}}), isEmpty);
    expect(plan([a], receives: false), isEmpty);
    expect(plan([a], receives: false, prefs: {'a1': {phone: true}}), hasLength(1));
  });

  test('alarma dirigida a un dispositivo concreto', () {
    final a = alarm(creator: me, recipients: [
      const AlarmRecipient(
        id: 'r1',
        recipientType: RecipientType.device,
        recipientId: tablet,
        userId: me,
        displayName: 'Tablet',
        permissionStatus: PermissionStatus.accepted,
        responseStatus: ResponseStatus.noResponse,
      ),
    ]);
    expect(plan([a], device: phone), isEmpty);
    expect(plan([a], device: tablet), hasLength(1));
  });

  test('canceladas no suenan', () {
    expect(plan([alarm(status: AlarmStatus.cancelled)]), isEmpty);
  });

  test('IDs nativos estables y distintos por ocurrencia', () {
    final a = PlannedRing.nativeIdFor('a1', DateTime.utc(2026, 10, 4, 13));
    final b = PlannedRing.nativeIdFor('a1', DateTime.utc(2026, 10, 5, 13));
    expect(a, PlannedRing.nativeIdFor('a1', DateTime.utc(2026, 10, 4, 13)));
    expect(a, isNot(b));
    expect(a, greaterThan(0));
  });
}
