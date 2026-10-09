import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../http/api_exception.dart';
import '../http/request_utils.dart';
import 'chat/chat_service.dart';
import 'devices/devices_service.dart';
import 'notifications/notification_service.dart';
import 'parser/parser_service.dart';
import 'sync/sync_service.dart';

/// `/api/devices/...`
Router devicesRoutes(DevicesService devices) {
  final router = Router();

  router.get('/', (Request req) async {
    final list = await devices.list(req.userId);
    return jsonResponse({'devices': [for (final d in list) d.toJson()]});
  });

  router.post('/', (Request req) async {
    final input = await req.readBody(DeviceInput.fromJson);
    return jsonResponse((await devices.register(req.userId, input)).toJson(), status: 201);
  });

  router.put('/<id>', (Request req, String id) async {
    final body = await req.readJson();
    final device = await devices.update(
      req.userId,
      requireUuid(id),
      name: body['device_name'] as String?,
      receivesAlarms: body['receives_alarms'] as bool?,
    );
    return jsonResponse(device.toJson());
  });

  router.delete('/<id>', (Request req, String id) async {
    await devices.remove(req.userId, requireUuid(id));
    return noContent();
  });

  return router;
}

/// `/api/notifications/...`
Router notificationsRoutes(NotificationService notifications) {
  final router = Router();

  router.get('/', (Request req) async {
    final before = DateTime.tryParse(req.query('before') ?? '');
    final list = await notifications.list(
      req.userId,
      before: before?.toUtc(),
      limit: req.queryInt('limit', defaultValue: 50, min: 1, max: 100),
    );
    return jsonResponse({
      'notifications': [for (final n in list) n.toJson()],
      'unread': await notifications.unreadCount(req.userId),
    });
  });

  router.post('/read-all', (Request req) async {
    await notifications.markAllRead(req.userId);
    return noContent();
  });

  router.post('/<id>/read', (Request req, String id) async {
    if (!await notifications.markRead(req.userId, requireUuid(id))) {
      throw const ApiException.notFound();
    }
    return noContent();
  });

  return router;
}

/// `/api/sync`
Router syncRoutes(SyncService sync, DevicesService devices) {
  final router = Router();
  router.get('/', (Request req) async {
    final cursor = req.queryInt('cursor', defaultValue: 0, min: 0);
    final deviceId = req.deviceId;
    if (deviceId != null) await devices.touch(req.userId, deviceId);
    return jsonResponse((await sync.pull(req.userId, cursor)).toJson());
  });
  return router;
}

/// `/api/parser/parse`
Router parserRoutes(ParserService parser) {
  final router = Router();
  router.post('/parse', (Request req) async {
    final body = await req.readJson();
    return jsonResponse((await parser.parse(req.userId, body)).toJson());
  });
  return router;
}

/// `/api/chat/...`
Router chatRoutes(ChatService chat) {
  final router = Router();

  router.get('/sessions', (Request req) async {
    final list = await chat.sessions(req.userId);
    return jsonResponse({'sessions': [for (final s in list) s.toJson()]});
  });

  router.post('/sessions', (Request req) async {
    final body = await req.readJson();
    final session = await chat.createSession(
      req.userId,
      id: body['id'] as String?,
      title: body['title'] as String?,
    );
    return jsonResponse(session.toJson(), status: 201);
  });

  router.delete('/sessions/<id>', (Request req, String id) async {
    await chat.deleteSession(req.userId, requireUuid(id));
    return noContent();
  });

  router.get('/sessions/<id>/messages', (Request req, String id) async {
    final list = await chat.messages(req.userId, requireUuid(id));
    return jsonResponse({'messages': [for (final m in list) m.toJson()]});
  });

  router.post('/sessions/<id>/messages', (Request req, String id) async {
    final sessionId = requireUuid(id);
    final body = await req.readJson();
    final List<ChatMessage> messages;
    try {
      messages = [
        for (final m in (body['messages'] as List).cast<Map<String, dynamic>>())
          ChatMessage.fromJson({...m, 'session_id': sessionId}),
      ];
    } catch (_) {
      throw const ApiException.badRequest('Los mensajes no son válidos.');
    }
    final saved = await chat.append(req.userId, sessionId, messages);
    return jsonResponse({'messages': [for (final m in saved) m.toJson()]}, status: 201);
  });

  return router;
}
