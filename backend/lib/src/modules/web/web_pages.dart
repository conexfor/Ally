import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../config/app_config.dart';
import '../../db/database.dart';
import '../../http/api_exception.dart';
import '../auth/auth_service.dart';
import 'privacy_policy.dart';

/// Páginas web públicas que abren los enlaces enviados por correo o
/// compartidos. Funcionan en cualquier navegador aunque la app no esté
/// instalada; si lo está (Android App Links), Android abre la app directamente.
Router webPages(AppConfig config, AuthService auth, Db db) {
  final router = Router();

  router.get('/reset-password', (Request req) {
    final token = req.url.queryParameters['token'] ?? '';
    if (token.isEmpty) return _page('Enlace no válido', '<p>Abre el enlace que recibiste por correo.</p>');
    return _page('Nueva contraseña', '''
      <form method="post" action="/reset-password">
        <input type="hidden" name="token" value="${_esc(token)}">
        <label>Nueva contraseña<input type="password" name="password" minlength="8" required autocomplete="new-password"></label>
        <label>Repite la contraseña<input type="password" name="confirm" minlength="8" required autocomplete="new-password"></label>
        <p class="hint">Mínimo 8 caracteres, con letras y números.</p>
        <button type="submit">Guardar contraseña</button>
      </form>
      <p class="alt"><a href="ally://reset-password?token=${Uri.encodeQueryComponent(token)}">Abrir en la app</a></p>
    ''');
  });

  router.post('/reset-password', (Request req) async {
    final form = Uri.splitQueryString(await req.readAsString());
    final password = form['password'] ?? '';
    if (password != form['confirm']) {
      return _page('Nueva contraseña', '<p class="error">Las contraseñas no coinciden. Vuelve atrás e inténtalo de nuevo.</p>');
    }
    try {
      await auth.resetPassword(form['token'] ?? '', password);
      return _page('Contraseña actualizada',
          '<p>Ya puedes iniciar sesión en la app con tu nueva contraseña.</p>${_openApp()}');
    } on ApiException catch (e) {
      return _page('No se pudo cambiar', '<p class="error">${_esc(e.message)}</p>');
    }
  });

  router.get('/verify-email', (Request req) async {
    try {
      await auth.verifyEmail(req.url.queryParameters['token'] ?? '');
      return _page('Correo confirmado', '<p>¡Listo! Tu correo quedó verificado.</p>${_openApp()}');
    } on ApiException catch (e) {
      return _page('No se pudo verificar', '<p class="error">${_esc(e.message)}</p>');
    }
  });

  router.get('/c/<code>', (Request req, String raw) async {
    final code = InvitationCode.parsePayload(raw);
    final row = code == null
        ? null
        : await db.one(
            'SELECT u.display_name FROM invitation_codes c JOIN users u ON u.id = c.user_id '
            'WHERE c.code = @c AND c.expires_at > now() AND c.uses < c.max_uses AND u.deleted_at IS NULL',
            {'c': code},
          );
    if (row == null) {
      return _page('Invitación no válida', '<p>El código no existe o ya caducó. Pide uno nuevo.</p>');
    }
    // _page escapa el título.
    final name = row['display_name'] as String;
    final store = config.playStoreUrl == null
        ? ''
        : '<a class="button secondary" href="${_esc(config.playStoreUrl!)}">Descargar en Google Play</a>';
    return _page('$name te invitó a Ally', '''
      <p>Conéctate para enviaros alarmas. Tu código es:</p>
      <p class="code">${code!.substring(0, 4)}-${code.substring(4)}</p>
      <a class="button" href="ally://connect?code=$code">Abrir en la app</a>
      $store
      <p class="hint">Si ya tienes la app, también puedes ir a Personas → Agregar → Escanear y escribir el código.</p>
    ''');
  });

  router.get('/privacy', (Request _) => _page('Política de privacidad', privacyPolicyHtml, wide: true));

  router.get('/.well-known/assetlinks.json', (Request _) {
    final package = config.androidPackageName;
    final statements = package == null || config.androidCertFingerprints.isEmpty
        ? <Object>[]
        : [
            {
              'relation': ['delegate_permission/common.handle_all_urls'],
              'target': {
                'namespace': 'android_app',
                'package_name': package,
                'sha256_cert_fingerprints': config.androidCertFingerprints,
              },
            },
          ];
    return Response.ok(jsonEncode(statements), headers: {
      'content-type': 'application/json',
      'cache-control': 'public, max-age=3600',
    });
  });

  return router;
}

String _openApp() => '<a class="button" href="ally://open">Abrir la app</a>';

String _esc(String value) => const HtmlEscape().convert(value);

Response _page(String title, String body, {bool wide = false}) => Response.ok(
      '''<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${_esc(title)} · Ally</title>
<style>
  :root { color-scheme: light dark; --p: #4f46e5; }
  body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 0; background: #f7f7fb; color: #15162b; }
  @media (prefers-color-scheme: dark) { body { background: #0f1020; color: #f2f2f7; } main { background: #1a1b2e !important; } }
  main { max-width: ${wide ? 720 : 420}px; margin: 40px auto; padding: 32px; background: #fff; border-radius: 20px; }
  .logo { width: 52px; height: 52px; border-radius: 16px; background: var(--p); color: #fff; display: grid; place-items: center; font-size: 28px; }
  h1 { font-size: 26px; margin: 20px 0 12px; }
  label { display: block; margin: 14px 0 4px; font-weight: 600; }
  input { width: 100%; box-sizing: border-box; padding: 14px; border-radius: 12px; border: 1px solid #c8c8d8; font-size: 16px; margin-top: 6px; }
  button, .button { display: block; width: 100%; box-sizing: border-box; text-align: center; padding: 14px; margin-top: 18px; border: 0; border-radius: 12px; background: var(--p); color: #fff; font-size: 16px; font-weight: 600; text-decoration: none; }
  .secondary { background: transparent; color: var(--p); border: 1.5px solid var(--p); }
  .hint { color: #6b6b80; font-size: 14px; } .error { color: #dc2626; } .alt { text-align: center; }
  .code { font-size: 30px; letter-spacing: 6px; font-weight: 700; text-align: center; }
  a { color: var(--p); }
</style></head>
<body><main><div class="logo">⏰</div><h1>${_esc(title)}</h1>$body</main></body></html>''',
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'",
      },
    );
