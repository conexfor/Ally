import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../http/api_exception.dart';
import '../../http/request_utils.dart';
import '../auth/auth_service.dart';
import 'users_repository.dart';

/// Perfil del usuario autenticado (`/api/me`) y búsqueda (`/api/users`).
Router meRoutes(UsersRepository users, AuthService auth) {
  final router = Router();

  router.get('/me', (Request req) async {
    final user = await users.findById(req.userId);
    if (user == null) throw const ApiException.unauthorized();
    return jsonResponse(user.toJson());
  });

  router.put('/me', (Request req) async {
    final body = await req.readJson();
    final errors = FieldErrors();
    String? displayName;
    String? username;
    String? phone;
    var clearPhone = false;
    if (body.containsKey('display_name')) {
      displayName = (body['display_name'] as String? ?? '').trim();
      errors.check('display_name', Validators.displayName(displayName));
    }
    if (body.containsKey('username')) {
      username = Validators.normalizeUsername(body['username'] as String? ?? '');
      errors.check('username', Validators.username(username));
    }
    if (body.containsKey('phone')) {
      final raw = body['phone'] as String?;
      if (raw == null || raw.trim().isEmpty) {
        clearPhone = true;
      } else {
        errors.check('phone', Validators.optionalPhone(raw));
        phone = Validators.normalizePhone(raw);
      }
    }
    final timezone = body['timezone'] as String?;
    if (timezone != null && !ZonedSchedule.isValidTimezone(timezone)) {
      errors.add('timezone', 'La zona horaria no es válida.');
    }
    final language = body['language'] as String?;
    if (language != null && !RegExp(r'^[a-z]{2}(-[A-Z]{2})?$').hasMatch(language)) {
      errors.add('language', 'El idioma no es válido.');
    }
    errors.throwIfAny();

    final me = req.userId;
    if (username != null) {
      final existing = await users.findByUsername(username);
      if (existing != null && existing.id != me) {
        throw ApiException.validation({'username': 'Ese nombre de usuario ya está en uso.'});
      }
    }
    if (phone != null) {
      final existing = await users.findByPhone(phone);
      if (existing != null && existing.id != me) {
        throw ApiException.validation({'phone': 'Ese teléfono ya está asociado a otra cuenta.'});
      }
    }
    final user = await users.updateProfile(
      me,
      displayName: displayName,
      username: username,
      phone: phone,
      clearPhone: clearPhone,
      timezone: timezone,
      language: language,
    );
    return jsonResponse(user.toJson());
  });

  router.put('/me/password', (Request req) async {
    final body = await req.readJson();
    await auth.changePassword(
      req.userId,
      body['current_password'] as String? ?? '',
      body['new_password'] as String? ?? '',
    );
    return noContent();
  });

  router.put('/me/email', (Request req) async {
    final body = await req.readJson();
    final user = await auth.changeEmail(
      req.userId,
      body['email'] as String? ?? '',
      body['password'] as String? ?? '',
    );
    return jsonResponse(user.toJson());
  });

  router.post('/me/email/resend', (Request req) async {
    await auth.resendVerification(req.userId);
    return jsonResponse({'message': 'Te enviamos un nuevo enlace de verificación.'});
  });

  final avatars = AvatarRepository(users.db);

  router.post('/me/avatar', (Request req) async {
    final bytes = await req.readBytes(AvatarRepository.maxBytes);
    final type = AvatarRepository.detectContentType(bytes);
    if (type == null) {
      throw const ApiException.badRequest('La imagen debe ser JPG, PNG o WebP.');
    }
    await avatars.save(req.userId, type, bytes);
    return jsonResponse((await users.findById(req.userId))!.toJson());
  });

  router.delete('/me/avatar', (Request req) async {
    await avatars.remove(req.userId);
    return jsonResponse((await users.findById(req.userId))!.toJson());
  });

  router.get('/users/<id>/avatar', (Request req, String id) async {
    final avatar = await avatars.load(req.userId, requireUuid(id));
    if (avatar == null) throw const ApiException.notFound();
    return Response.ok(avatar.bytes, headers: {
      'content-type': avatar.contentType,
      'cache-control': 'private, max-age=86400',
    });
  });

  router.delete('/me', (Request req) async {
    await auth.logoutEverywhere(req.userId);
    await users.deleteAccount(req.userId);
    return noContent();
  });

  router.post('/me/logout-all', (Request req) async {
    await auth.logoutEverywhere(req.userId);
    return noContent();
  });

  router.get('/me/settings', (Request req) async =>
      jsonResponse((await users.getSettings(req.userId)).toJson()));

  router.put('/me/settings', (Request req) async {
    final settings = await req.readBody(UserSettings.fromJson);
    if (settings.defaultSnoozeMinutes < 1 || settings.defaultSnoozeMinutes > 1440) {
      throw ApiException.validation({'default_snooze_minutes': 'Elige entre 1 y 1440 minutos.'});
    }
    return jsonResponse((await users.saveSettings(req.userId, settings)).toJson());
  });

  router.get('/users/search', (Request req) async {
    final q = req.query('q') ?? '';
    if (q.length < 2) return jsonResponse({'users': <Object>[]});
    final results = await users.search(q, excludeUserId: req.userId);
    return jsonResponse({'users': [for (final u in results) u.toJson()]});
  });

  return router;
}
