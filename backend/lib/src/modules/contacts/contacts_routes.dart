import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../http/api_exception.dart';
import '../../http/request_utils.dart';
import 'contacts_service.dart';

/// `/api/contacts/...`
Router contactsRoutes(ContactsService contacts) {
  final router = Router();

  router.get('/', (Request req) async {
    final list = await contacts.list(req.userId);
    return jsonResponse({'contacts': [for (final c in list) c.toJson()]});
  });

  router.get('/requests', (Request req) async {
    final list = (await contacts.list(req.userId))
        .where((c) => c.status == ConnectionStatus.pending)
        .toList();
    return jsonResponse({'requests': [for (final c in list) c.toJson()]});
  });

  router.post('/request', (Request req) async {
    final target = await req.readBody(ConnectionTarget.fromJson);
    return jsonResponse((await contacts.request(req.userId, target)).toJson(), status: 201);
  });

  router.post('/invitation', (Request req) async =>
      jsonResponse((await contacts.invitationCode(req.userId)).toJson()));

  router.post('/connect', (Request req) async {
    final body = await req.readJson();
    final code = body['code'] as String?;
    if (code == null) throw const ApiException.badRequest('Escribe o escanea un código.');
    return jsonResponse((await contacts.connectWithCode(req.userId, code)).toJson());
  });

  router.get('/<id>', (Request req, String id) async =>
      jsonResponse((await contacts.get(req.userId, requireUuid(id))).toJson()));

  router.post('/<id>/accept', (Request req, String id) async =>
      jsonResponse((await contacts.accept(req.userId, requireUuid(id))).toJson()));

  router.post('/<id>/reject', (Request req, String id) async {
    await contacts.reject(req.userId, requireUuid(id));
    return noContent();
  });

  router.post('/<id>/block', (Request req, String id) async {
    await contacts.block(req.userId, requireUuid(id));
    return noContent();
  });

  router.post('/<id>/unblock', (Request req, String id) async {
    await contacts.unblock(req.userId, requireUuid(id));
    return noContent();
  });

  router.delete('/<id>', (Request req, String id) async {
    await contacts.remove(req.userId, requireUuid(id));
    return noContent();
  });

  router.put('/<id>/permissions', (Request req, String id) async {
    final permissions = await req.readBody(ConnectionPermissions.fromJson);
    return jsonResponse(
      (await contacts.updatePermissions(req.userId, requireUuid(id), permissions)).toJson(),
    );
  });

  return router;
}
