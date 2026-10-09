import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../http/api_exception.dart';
import '../../http/request_utils.dart';
import '../users/users_repository.dart';
import 'auth_service.dart';

/// Rutas públicas de autenticación (`/api/auth/...`).
Router authRoutes(AuthService auth, UsersRepository users) {
  final router = Router();

  router.post('/register', (Request req) async {
    final input = await req.readBody(RegisterInput.fromJson);
    return jsonResponse((await auth.register(input, deviceId: req.deviceId)).toJson(), status: 201);
  });

  router.post('/login', (Request req) async {
    final body = await req.readJson();
    final identifier = (body['identifier'] ?? body['email'] ?? body['username']) as String?;
    final password = body['password'] as String?;
    if (identifier == null || identifier.trim().isEmpty || password == null || password.isEmpty) {
      throw ApiException.validation({'identifier': 'Escribe tu correo o usuario y tu contraseña.'});
    }
    return jsonResponse((await auth.login(identifier, password, deviceId: req.deviceId)).toJson());
  });

  router.post('/google', (Request req) async {
    final body = await req.readJson();
    final token = body['id_token'] as String?;
    if (token == null) throw const ApiException.badRequest('Falta el token de Google.');
    final session = await auth.loginWithGoogle(
      token,
      timezone: body['timezone'] as String? ?? 'UTC',
      deviceId: req.deviceId,
    );
    return jsonResponse(session.toJson());
  });

  router.post('/apple', (Request req) async {
    final body = await req.readJson();
    final token = body['id_token'] as String?;
    if (token == null) throw const ApiException.badRequest('Falta el token de Apple.');
    final session = await auth.loginWithApple(
      token,
      fullName: body['full_name'] as String?,
      timezone: body['timezone'] as String? ?? 'UTC',
      deviceId: req.deviceId,
    );
    return jsonResponse(session.toJson());
  });

  router.post('/refresh', (Request req) async {
    final body = await req.readJson();
    final token = body['refresh_token'] as String?;
    if (token == null) throw const ApiException.unauthorized();
    return jsonResponse((await auth.refresh(token)).toJson());
  });

  router.post('/logout', (Request req) async {
    final body = await req.readJson();
    final token = body['refresh_token'] as String?;
    if (token != null) await auth.logout(token);
    return noContent();
  });

  router.post('/password/forgot', (Request req) async {
    final body = await req.readJson();
    final email = body['email'] as String? ?? '';
    final error = Validators.email(email);
    if (error != null) throw ApiException.validation({'email': error});
    await auth.requestPasswordReset(email);
    return jsonResponse({
      'message': 'Si existe una cuenta con ese correo, te enviamos un enlace para restablecer la contraseña.',
    });
  });

  router.post('/password/reset', (Request req) async {
    final body = await req.readJson();
    await auth.resetPassword(body['token'] as String? ?? '', body['password'] as String? ?? '');
    return jsonResponse({'message': 'Tu contraseña se actualizó. Ya puedes iniciar sesión.'});
  });

  router.post('/email/verify', (Request req) async {
    final body = await req.readJson();
    final user = await auth.verifyEmail(body['token'] as String? ?? '');
    return jsonResponse(user.toJson());
  });

  router.get('/username-available', (Request req) async {
    final username = Validators.normalizeUsername(req.query('username') ?? '');
    final error = Validators.username(username);
    final available = error == null && !await users.usernameExists(username);
    return jsonResponse({'username': username, 'available': available, 'error': error});
  });

  return router;
}
