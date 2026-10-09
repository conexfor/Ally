import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../http/api_exception.dart';
import '../../http/request_utils.dart';
import 'groups_service.dart';

/// `/api/groups/...`
Router groupsRoutes(GroupsService groups) {
  final router = Router();

  router.get('/', (Request req) async {
    final list = await groups.list(req.userId);
    return jsonResponse({'groups': [for (final g in list) g.toJson()]});
  });

  router.post('/', (Request req) async {
    final input = await req.readBody(GroupInput.fromJson);
    return jsonResponse((await groups.create(req.userId, input)).toJson(), status: 201);
  });

  router.get('/<id>', (Request req, String id) async =>
      jsonResponse((await groups.get(req.userId, requireUuid(id))).toJson()));

  router.put('/<id>', (Request req, String id) async {
    final input = await req.readBody(GroupInput.fromJson);
    return jsonResponse((await groups.update(req.userId, requireUuid(id), input)).toJson());
  });

  router.delete('/<id>', (Request req, String id) async {
    await groups.delete(req.userId, requireUuid(id));
    return noContent();
  });

  router.post('/<id>/members', (Request req, String id) async {
    final body = await req.readJson();
    final ids = List<String>.from(body['user_ids'] as List? ?? const []);
    return jsonResponse((await groups.addMembers(req.userId, requireUuid(id), ids)).toJson());
  });

  router.delete('/<id>/members/<userId>', (Request req, String id, String userId) async {
    await groups.removeMember(req.userId, requireUuid(id), requireUuid(userId));
    return noContent();
  });

  router.put('/<id>/members/<userId>/role', (Request req, String id, String userId) async {
    final body = await req.readJson();
    final GroupRole role;
    try {
      role = GroupRole.fromWire(body['role'] as String? ?? '');
    } catch (_) {
      throw const ApiException.badRequest('Rol no válido.');
    }
    return jsonResponse(
      (await groups.setRole(req.userId, requireUuid(id), requireUuid(userId), role)).toJson(),
    );
  });

  router.post('/<id>/accept', (Request req, String id) async =>
      jsonResponse((await groups.acceptInvitation(req.userId, requireUuid(id))).toJson()));

  router.post('/<id>/leave', (Request req, String id) async {
    await groups.removeMember(req.userId, requireUuid(id), req.userId);
    return noContent();
  });

  router.put('/<id>/me', (Request req, String id) async {
    final body = await req.readJson();
    return jsonResponse((await groups.updateMySettings(
      req.userId,
      requireUuid(id),
      allowGroupAlarms: body['allow_group_alarms'] as bool? ?? true,
      autoAccept: body['auto_accept'] as bool? ?? true,
    ))
        .toJson());
  });

  return router;
}
