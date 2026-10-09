import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../http/api_exception.dart';
import '../../http/request_utils.dart';
import 'alarms_service.dart';
import 'history_service.dart';

/// `/api/alarms/...`
Router alarmsRoutes(AlarmsService alarms) {
  final router = Router();

  DateTime? parseDate(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const ApiException.badRequest('Fecha no válida.');
    return parsed.toUtc();
  }

  router.get('/', (Request req) async {
    final list = await alarms.list(
      req.userId,
      scope: req.query('scope') ?? 'all',
      from: parseDate(req.query('from')),
      to: parseDate(req.query('to')),
    );
    return jsonResponse({'alarms': [for (final a in list) a.toJson()]});
  });

  router.post('/', (Request req) async {
    final input = await req.readBody(AlarmInput.fromJson);
    return jsonResponse(
      (await alarms.create(req.userId, input, deviceId: req.deviceId)).toJson(),
      status: 201,
    );
  });

  router.get('/device-preferences', (Request req) async =>
      jsonResponse({'preferences': await alarms.devicePreferences(req.userId)}));

  router.get('/<id>', (Request req, String id) async =>
      jsonResponse((await alarms.get(req.userId, requireUuid(id))).toJson()));

  router.put('/<id>', (Request req, String id) async {
    final input = await req.readBody(AlarmInput.fromJson);
    return jsonResponse(
      (await alarms.update(req.userId, requireUuid(id), input, deviceId: req.deviceId)).toJson(),
    );
  });

  router.delete('/<id>', (Request req, String id) async {
    await alarms.delete(req.userId, requireUuid(id), deviceId: req.deviceId);
    return noContent();
  });

  router.post('/<id>/cancel', (Request req, String id) async => jsonResponse(
        (await alarms.cancelNext(req.userId, requireUuid(id), deviceId: req.deviceId)).toJson(),
      ));

  Future<Response> respond(Request req, String id, ResponseStatus response) async {
    final body = await req.readJson();
    final occurrence = DateTime.tryParse(body['occurrence_at'] as String? ?? '');
    if (occurrence == null) throw const ApiException.badRequest('Falta la ocurrencia.');
    final alarm = await alarms.respond(
      req.userId,
      requireUuid(id),
      RespondInput(
        occurrenceAt: occurrence,
        response: response,
        snoozeMinutes: (body['snooze_minutes'] as num?)?.toInt(),
        deviceId: req.deviceId,
      ),
      deviceId: req.deviceId,
    );
    return jsonResponse(alarm.toJson());
  }

  router.post('/<id>/confirm', (Request req, String id) => respond(req, id, ResponseStatus.confirmed));
  router.post('/<id>/snooze', (Request req, String id) => respond(req, id, ResponseStatus.snoozed));
  router.post('/<id>/dismiss', (Request req, String id) => respond(req, id, ResponseStatus.dismissed));

  router.post('/<id>/accept', (Request req, String id) async => jsonResponse(
        (await alarms.setPermission(req.userId, requireUuid(id), accept: true, deviceId: req.deviceId))!
            .toJson(),
      ));

  router.post('/<id>/reject', (Request req, String id) async {
    await alarms.setPermission(req.userId, requireUuid(id), accept: false, deviceId: req.deviceId);
    return noContent();
  });

  router.get('/<id>/responses', (Request req, String id) async {
    final list = await alarms.responses(req.userId, requireUuid(id));
    return jsonResponse({'responses': [for (final r in list) r.toJson()]});
  });

  router.put('/<id>/devices/<deviceId>', (Request req, String id, String deviceId) async {
    final body = await req.readJson();
    final enabled = body['enabled'];
    if (enabled is! bool) throw const ApiException.badRequest('Indica si el dispositivo está activo.');
    await alarms.setDevicePreference(req.userId, requireUuid(id), requireUuid(deviceId), enabled);
    return noContent();
  });

  return router;
}

/// `/api/history` y `/api/stats`.
Router historyRoutes(HistoryService history) {
  final router = Router();

  router.get('/history', (Request req) async {
    final before = DateTime.tryParse(req.query('before') ?? '');
    final entries = await history.history(
      req.userId,
      filter: HistoryFilter.parse(req.query('filter')),
      before: before?.toUtc(),
      limit: req.queryInt('limit', defaultValue: 50, min: 1, max: 100),
    );
    return jsonResponse({'entries': [for (final e in entries) e.toJson()]});
  });

  router.get('/stats', (Request req) async {
    final all = req.query('period') == 'all';
    return jsonResponse({
      'period': all ? 'all' : 'month',
      'user': (await history.stats(req.userId, since: all ? DateTime.utc(2000) : null)).toJson(),
      'groups': [for (final g in await history.groupStats(req.userId)) g.toJson()],
    });
  });

  return router;
}
