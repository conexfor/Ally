import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';

import '../application/assistant/chat_controller.dart';
import '../application/session_controller.dart';
import '../core/errors/app_exception.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common.dart';
import '../core/widgets/ui.dart';
import '../features/alarms/ring_screen.dart';
import '../features/auth/lock_screen.dart';
import '../services/system_channel.dart';
import 'providers.dart';
import 'router.dart';

class AllyApp extends ConsumerStatefulWidget {
  const AllyApp({super.key});

  @override
  ConsumerState<AllyApp> createState() => _AllyAppState();
}

class _AllyAppState extends ConsumerState<AllyApp> {
  StreamSubscription<Uri>? _links;
  bool _askedNotifications = false;

  @override
  void initState() {
    super.initState();
    final services = ref.read(appServicesProvider);
    final session = ref.read(sessionProvider.notifier);
    services.notifications.onOpenRoute = _open;
    session.onOpenRoute = _open;
    ref.read(chatControllerProvider.notifier).onNavigate = _open;
    unawaited(_start());
  }

  /// Sin permiso de notificaciones Android descarta la pantalla de la alarma
  /// (Aceptar/Posponer) y los avisos de voz. Se pide una vez por arranque; si
  /// ya se negó antes, se explica y se ofrece abrir los ajustes.
  Future<void> _checkNotifications() async {
    if (_askedNotifications || ref.read(sessionProvider) is! SignedIn) return;
    // Se marca antes de esperar: al arrancar llegan dos avisos casi a la vez
    // (restaurar sesión y cambio de estado) y Android solo admite una petición.
    _askedNotifications = true;
    final notifications = ref.read(appServicesProvider).notifications;
    try {
      if (await notifications.notificationsEnabled()) return;
      if (await notifications.requestNotificationsPermission()) return;
    } catch (e) {
      debugPrint('Permiso de notificaciones: $e');
      return;
    }
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final open = await confirmDialog(
      context,
      title: 'Activa las notificaciones',
      message: 'Sin ellas, cuando suene una alarma no aparecerá la pantalla para aceptarla o '
          'posponerla, ni el aviso «Ally te escucha». Actívalas en los ajustes del teléfono.',
      confirm: 'Abrir ajustes',
    );
    if (open) await SystemChannel.openNotificationSettings();
  }

  Future<void> _start() async {
    await ref.read(sessionProvider.notifier).restore();
    unawaited(_checkNotifications());
    final launch = await ref.read(appServicesProvider).notifications.launchRoute();
    if (launch != null) _open(launch);
    final links = AppLinks();
    final initial = await links.getInitialLink();
    if (initial != null) _handleLink(initial);
    _links = links.uriLinkStream.listen(_handleLink);
  }

  /// Enlaces que abren la app:
  /// - `ally://connect?code=X` (QR) y `https://<dominio>/c/X` (invitación);
  /// - `.../reset-password?token=…` (recuperar contraseña);
  /// - `.../verify-email?token=…` (confirmar correo).
  void _handleLink(Uri uri) {
    final String action;
    if (uri.scheme == 'ally') {
      action = uri.host;
    } else if (uri.scheme == 'https' && uri.pathSegments.isNotEmpty) {
      action = uri.pathSegments.first == 'c' ? 'connect' : uri.pathSegments.first;
    } else {
      return;
    }
    final token = uri.queryParameters['token'] ?? '';
    switch (action) {
      case 'connect':
        final raw = uri.scheme == 'https' && uri.pathSegments.length > 1
            ? uri.pathSegments[1]
            : uri.queryParameters['code'] ?? '';
        final code = InvitationCode.parsePayload(raw);
        if (code != null) _open('/contacts/add?tab=code&code=$code');
      case 'reset-password':
        _open('/reset-password?token=${Uri.encodeQueryComponent(token)}');
      case 'verify-email':
        unawaited(_verifyEmail(token));
    }
  }

  Future<void> _verifyEmail(String token) async {
    final messenger = rootMessengerKey.currentState;
    try {
      await ref.read(sessionProvider.notifier).verifyEmail(token);
      messenger?.showSnackBar(const SnackBar(content: Text('¡Correo confirmado!')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }

  void _open(String route) {
    // Espera a que exista el árbol de navegación.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(routerProvider).push(route);
    });
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Tras iniciar sesión también se comprueba el permiso de notificaciones.
    ref.listen(sessionProvider, (_, next) {
      if (next is SignedIn) unawaited(_checkNotifications());
    });
    // ¿La alarma abrió la app? Sí si ya sonaba al arrancar (la abrió su
    // notificación) o si empezó a sonar con la app en segundo plano.
    ref.listen(ringingProvider, (previous, next) {
      final sonando = next.value?.isNotEmpty ?? false;
      final antes = previous?.value?.isNotEmpty ?? false;
      if (sonando && !antes) {
        RingLaunch.openedByAlarm =
            previous?.value == null || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
      }
    });
    return MaterialApp.router(
      title: 'Ally',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      // Bloqueo con huella sobre toda la app.
      // En escritorio se conserva el ancho de un smartphone.
      builder: (context, child) => PhoneFrame(child: AppLockGate(child: child ?? const SizedBox.shrink())),
      scaffoldMessengerKey: rootMessengerKey,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
