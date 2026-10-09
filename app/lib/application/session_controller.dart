import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ally_core/ally_core.dart';

import '../app/providers.dart';
import '../core/errors/app_exception.dart';

import '../services/alarm_event_handler.dart';
import '../services/background_sync.dart';
import '../services/push_service.dart';
import '../services/sync_engine.dart';
import '../services/voice_channel.dart';

sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

class SignedOut extends SessionState {
  /// Ya vio la presentación: se muestra directamente el inicio de sesión.
  final bool onboardingSeen;
  const SignedOut({this.onboardingSeen = true});
}

class SignedIn extends SessionState {
  final UserProfile user;

  /// Recién registrado con Google/Apple: conviene revisar el usuario.
  final bool isNewUser;
  const SignedIn(this.user, {this.isNewUser = false});
}

/// Estado de la sesión y tareas que acompañan al inicio de sesión:
/// registrar el dispositivo, activar push, sincronizar y reprogramar.
class SessionController extends Notifier<SessionState> {
  PushService? _push;
  AlarmEventHandler? _events;
  Timer? _periodicSync;
  AppLifecycleListener? _lifecycle;

  /// Navegación solicitada desde notificaciones.
  void Function(String route)? onOpenRoute;

  @override
  SessionState build() {
    ref.onDispose(_stopBackground);
    return const SessionLoading();
  }

  Future<void> restore() async {
    try {
      await _restore();
    } catch (e) {
      // Nunca dejar la app en la pantalla de carga.
      debugPrint('AllyInicio no se pudo restaurar la sesión: $e');
      if (state is SessionLoading) state = const SignedOut();
    }
  }

  Future<void> _restore() async {
    final services = ref.read(appServicesProvider);
    services.client.onSessionExpired = _onExpired;
    _events ??= AlarmEventHandler(services);
    final reloj = Stopwatch()..start();
    var user = await services.auth.restore();
    debugPrint('AllyInicio perfil local: ${reloj.elapsedMilliseconds} ms');
    if (user != null && await _storage.read(key: _rememberKey) == 'false') {
      // El usuario pidió no recordar la sesión: se cierra al reabrir la app.
      await services.auth.logout();
      await _storage.delete(key: _rememberKey);
      user = null;
    }
    if (user == null) {
      state = SignedOut(onboardingSeen: await _onboardingSeen());
      return;
    }
    state = SignedIn(user);
    debugPrint('AllyInicio sesión restaurada en ${reloj.elapsedMilliseconds} ms (sale de la pantalla de carga)');
    unawaited(_afterSignIn());
  }

  Future<void> login(String identifier, String password, {bool remember = true}) async {
    final user = await ref.read(appServicesProvider).auth.login(identifier, password);
    await _storage.write(key: _rememberKey, value: '$remember');
    state = SignedIn(user);
    await _afterSignIn();
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final user = await ref.read(appServicesProvider).auth.register(
          email: email,
          password: password,
          username: username,
          displayName: displayName,
        );
    await _storage.delete(key: _rememberKey);
    state = SignedIn(user);
    await _afterSignIn();
  }

  Future<void> loginWithGoogle() async {
    await _storage.delete(key: _rememberKey);
    final (user, isNew) = await ref.read(appServicesProvider).auth.loginWithGoogle();
    state = SignedIn(user, isNewUser: isNew);
    await _afterSignIn();
  }

  Future<void> loginWithApple() async {
    await _storage.delete(key: _rememberKey);
    final (user, isNew) = await ref.read(appServicesProvider).auth.loginWithApple();
    state = SignedIn(user, isNewUser: isNew);
    await _afterSignIn();
  }

  void updateUser(UserProfile user) => state = SignedIn(user);

  Future<void> logout() async {
    _stopBackground();
    await BackgroundSync.cancel();
    await ref.read(appServicesProvider).auth.logout();
    state = const SignedOut();
  }

  Future<void> deleteAccount() async {
    _stopBackground();
    await BackgroundSync.cancel();
    await ref.read(appServicesProvider).auth.deleteAccount();
    state = const SignedOut();
  }

  static const _storage = FlutterSecureStorage();
  static const _onboardingKey = 'onboarding_seen';
  static const _rememberKey = 'remember_session';

  Future<bool> _onboardingSeen() async => await _storage.read(key: _onboardingKey) == 'true';

  /// La presentación solo se muestra la primera vez.
  Future<void> markOnboardingSeen() => _storage.write(key: _onboardingKey, value: 'true');

  /// Verifica el correo con el token de un enlace y actualiza el perfil.
  Future<void> verifyEmail(String token) async {
    final services = ref.read(appServicesProvider);
    final user = await services.api.verifyEmail(token);
    if (state is SignedIn && (state as SignedIn).user.id == user.id) {
      await services.store.saveMe(user);
      state = SignedIn(user);
    }
  }

  /// Sincroniza y muestra avisos locales si no hay push.
  Future<SyncResult> syncNow() async {
    final services = ref.read(appServicesProvider);
    final result = await services.sync.sync();
    if (!(_push?.enabled ?? false)) {
      // Sin push: se avisa de lo nuevo (el cursor garantiza que no se repite).
      final recent = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      for (final n in result.newNotifications.where((n) => n.createdAt.isAfter(recent)).take(5)) {
        await services.notifications.showFor(n);
      }
    }
    return result;
  }

  Future<void> _afterSignIn() async {
    final services = ref.read(appServicesProvider);
    try {
      final profile = await services.auth.refreshProfile();
      if (profile != null && state is SignedIn) {
        state = SignedIn(profile, isNewUser: (state as SignedIn).isNewUser);
      }
    } on AppException catch (e) {
      if (e.isUnauthorized) return _onExpired();
    }
    await markOnboardingSeen();
    await services.devices.register();
    _push ??= PushService(services);
    await _push!.init(onOpenRoute: (route) => onOpenRoute?.call(route));
    await syncNow();
    // Después de sincronizar: las respuestas dadas desde la notificación con
    // la app cerrada necesitan las alarmas locales.
    _events?.start();
    await BackgroundSync.register();
    _startBackground();
  }

  void _startBackground() {
    _periodicSync?.cancel();
    _periodicSync = Timer.periodic(const Duration(minutes: 3), (_) => syncNow());
    _lifecycle ??= AppLifecycleListener(onResume: () => syncNow());
  }

  void _stopBackground() {
    // «Hey Ally» no debe seguir escuchando sin sesión.
    unawaited(VoiceChannel.setWakeWordEnabled(false).catchError((_) => const VoiceStatus()));
    _periodicSync?.cancel();
    _periodicSync = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _onExpired() {
    if (state is! SignedIn) return;
    _stopBackground();
    unawaited(ref.read(appServicesProvider).auth.logout());
    state = const SignedOut();
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);
