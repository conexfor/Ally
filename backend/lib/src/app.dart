import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config/app_config.dart';
import 'db/database.dart';
import 'http/middleware.dart';
import 'http/rate_limiter.dart';
import 'http/request_utils.dart';
import 'modules/alarms/alarm_maintenance_job.dart';
import 'modules/alarms/alarms_routes.dart';
import 'modules/alarms/alarms_service.dart';
import 'modules/alarms/history_service.dart';
import 'modules/alarms/recipient_planner.dart';
import 'modules/alarms/sequences_service.dart';
import 'modules/auth/auth_routes.dart';
import 'modules/auth/auth_service.dart';
import 'modules/chat/chat_service.dart';
import 'modules/contacts/contacts_routes.dart';
import 'modules/contacts/contacts_service.dart';
import 'modules/devices/devices_service.dart';
import 'modules/groups/groups_routes.dart';
import 'modules/groups/groups_service.dart';
import 'modules/misc_routes.dart';
import 'modules/notifications/email_sender.dart';
import 'modules/notifications/notification_service.dart';
import 'modules/notifications/push_sender.dart';
import 'modules/parser/parser_service.dart';
import 'modules/sync/sync_service.dart';
import 'modules/users/me_routes.dart';
import 'modules/users/users_repository.dart';
import 'modules/web/web_pages.dart';
import 'security/external_identity_verifier.dart';
import 'security/password_hasher.dart';
import 'security/token_service.dart';

/// Contenedor de dependencias de la aplicación (inyección manual).
class Application {
  final AppConfig config;
  final Db db;
  final TokenService tokens;
  final NotificationService notifications;
  final AuthService auth;
  final ContactsService contacts;
  final GroupsService groups;
  final AlarmsService alarms;
  final AlarmMaintenanceJob maintenance;
  final Handler handler;

  Application._({
    required this.config,
    required this.db,
    required this.tokens,
    required this.notifications,
    required this.auth,
    required this.contacts,
    required this.groups,
    required this.alarms,
    required this.maintenance,
    required this.handler,
  });

  factory Application.build(
    AppConfig config,
    Db db, {
    PushSender? push,
    EmailSender? email,
    ExternalIdentityVerifier? identities,
    PasswordHasher hasher = const PasswordHasher(),
  }) {
    final tokens = TokenService(config.jwtSecret, accessTokenTtl: config.accessTokenTtl);
    final pushSender =
        push ??
        (config.fcmServiceAccountJson != null
            ? FcmPushSender(serviceAccountJson: config.fcmServiceAccountJson!, projectId: config.fcmProjectId)
            : DisabledPushSender());
    final emailSender = email ?? (config.smtp != null ? SmtpEmailSender(config.smtp!) : LogEmailSender());
    final verifier =
        identities ??
        ExternalIdentityVerifier(googleClientIds: config.googleClientIds, appleClientIds: config.appleClientIds);

    final users = UsersRepository(db);
    final notifications = NotificationService(db, pushSender);
    final auth = AuthService(
      db: db,
      users: users,
      hasher: hasher,
      tokens: tokens,
      identities: verifier,
      email: emailSender,
      refreshTokenTtl: config.refreshTokenTtl,
      passwordResetUrl: config.passwordResetUrl,
      emailVerificationUrl: config.emailVerificationUrl,
    );
    final contacts = ContactsService(db, notifications);
    final groups = GroupsService(db, notifications);
    final alarms = AlarmsService(db, RecipientPlanner(contacts), notifications);
    final devices = DevicesService(db);
    final sync = SyncService(db, contacts, groups);
    final parser = ParserService(db, contacts, groups);
    final chat = ChatService(db);
    final history = HistoryService(db);

    final api = Router()
      ..get('/api/health', (Request _) async {
        // Comprueba también la base de datos para que el hosting detecte caídas.
        try {
          await db.query('SELECT 1');
          return jsonResponse({'status': 'ok'});
        } catch (_) {
          return jsonResponse({'status': 'unavailable', 'database': 'down'}, status: 503);
        }
      })
      ..mount('/api/auth/', authRoutes(auth, users).call)
      ..mount('/api/contacts/', contactsRoutes(contacts).call)
      ..mount('/api/groups/', groupsRoutes(groups).call)
      ..mount('/api/alarms/', alarmsRoutes(alarms).call)
      ..mount('/api/sequences/', sequencesRoutes(SequencesService(db, alarms, notifications)).call)
      ..mount('/api/devices/', devicesRoutes(devices).call)
      ..mount('/api/notifications/', notificationsRoutes(notifications).call)
      ..mount('/api/sync/', syncRoutes(sync, devices).call)
      ..mount('/api/parser/', parserRoutes(parser).call)
      ..mount('/api/chat/', chatRoutes(chat).call)
      ..mount('/api/', historyRoutes(history).call)
      ..mount('/api/', meRoutes(users, auth).call)
      ..mount('/', webPages(config, auth, db).call);

    bool isPublic(Request request) {
      final path = request.url.path;
      // Las páginas web públicas (fuera de /api) no requieren sesión.
      return path == 'api/health' || path.startsWith('api/auth/') || !path.startsWith('api/');
    }

    final handler = const Pipeline()
        .addMiddleware(requestLogger())
        .addMiddleware(securityHeaders())
        .addMiddleware(cors(config.corsOrigins))
        .addMiddleware(errorHandler())
        .addMiddleware(
          rateLimit(
            general: RateLimiter(maxRequests: config.rateLimitPerMinute),
            auth: RateLimiter(maxRequests: config.authRateLimitPerMinute),
            trustProxy: config.trustProxy,
          ),
        )
        .addMiddleware(authentication(tokens, isPublic: isPublic))
        .addHandler(_normalizeTrailingSlash(api.call));

    return Application._(
      config: config,
      db: db,
      tokens: tokens,
      notifications: notifications,
      auth: auth,
      contacts: contacts,
      groups: groups,
      alarms: alarms,
      maintenance: AlarmMaintenanceJob(db),
      handler: handler,
    );
  }
}

/// `/api/alarms` y `/api/alarms/` se tratan igual.
Handler _normalizeTrailingSlash(Handler inner) => (request) {
  final path = request.url.path;
  const roots = {
    'api/contacts',
    'api/groups',
    'api/alarms',
    'api/devices',
    'api/notifications',
    'api/sync',
    'api/sequences',
  };
  if (roots.contains(path)) {
    final url = request.requestedUri.replace(path: '${request.requestedUri.path}/');
    return inner(
      Request(
        request.method,
        url,
        headers: request.headers,
        body: request.read(),
        context: request.context,
        protocolVersion: request.protocolVersion,
      ),
    );
  }
  return inner(request);
};
