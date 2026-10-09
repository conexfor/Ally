import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:ally_core/ally_core.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/device_service.dart';
import '../local/local_store.dart';
import '../remote/ally_api.dart';
import '../remote/token_store.dart';

/// Registro, inicio y cierre de sesión. La identidad interna del usuario es
/// siempre su ID; correo, Google o Apple son solo formas de entrar.
class AuthRepository {
  final AllyApi api;
  final TokenStore tokens;
  final LocalStore store;
  final AlarmScheduler scheduler;

  AuthRepository(this.api, this.tokens, this.store, this.scheduler);

  bool _googleInitialized = false;

  Future<UserProfile> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async =>
      _start(await api.register(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
        timezone: await DeviceService.currentTimezone(),
      ));

  Future<UserProfile> login(String identifier, String password) async =>
      _start(await api.login(identifier.trim(), password));

  Future<(UserProfile, bool isNew)> loginWithGoogle() async {
    if (!Env.googleSignInConfigured) {
      throw const AppException('El inicio de sesión con Google no está configurado.');
    }
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(serverClientId: Env.googleServerClientId);
      _googleInitialized = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AppException('Inicio de sesión cancelado.', code: 'canceled');
      }
      throw const AppException('No se pudo iniciar sesión con Google.');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AppException('No se pudo iniciar sesión con Google.');
    final session = await api.loginWithGoogle(idToken, await DeviceService.currentTimezone());
    return (await _start(session), session.isNewUser);
  }

  Future<(UserProfile, bool isNew)> loginWithApple() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AppException('Inicio de sesión cancelado.', code: 'canceled');
      }
      throw const AppException('No se pudo iniciar sesión con Apple.');
    }
    final token = credential.identityToken;
    if (token == null) throw const AppException('No se pudo iniciar sesión con Apple.');
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .join(' ')
        .trim();
    final session = await api.loginWithApple(
      token,
      name.isEmpty ? null : name,
      await DeviceService.currentTimezone(),
    );
    return (await _start(session), session.isNewUser);
  }

  Future<String> forgotPassword(String email) => api.forgotPassword(email.trim());

  Future<String> resetPassword(String token, String password) => api.resetPassword(token, password);

  Future<UserProfile> _start(AuthSession session) async {
    await tokens.save(accessToken: session.accessToken, refreshToken: session.refreshToken);
    await store.saveMe(session.user);
    return session.user;
  }

  /// Perfil guardado (permite abrir la app sin conexión).
  Future<UserProfile?> restore() async {
    // Los tokens ya se cargaron en AppServices.create (leer el almacenamiento
    // seguro es lento): no se repite.
    if (!tokens.hasSession) return null;
    return store.me();
  }

  Future<UserProfile?> refreshProfile() async {
    try {
      final me = await api.me();
      await store.saveMe(me);
      await store.saveSettings(await api.settings());
      return me;
    } on AppException catch (e) {
      if (e.isNetwork) return store.me();
      rethrow;
    }
  }

  Future<UserProfile> updateProfile(Map<String, Object?> changes) async {
    final me = await api.updateMe(changes);
    await store.saveMe(me);
    return me;
  }

  Future<UserSettings> saveSettings(UserSettings settings) async {
    final saved = await api.saveSettings(settings);
    await store.saveSettings(saved);
    return saved;
  }

  Future<void> changePassword(String current, String next) => api.changePassword(current, next);

  Future<UserProfile> uploadAvatar(List<int> bytes) async {
    final me = await api.uploadAvatar(bytes);
    await store.saveMe(me);
    return me;
  }

  Future<UserProfile> removeAvatar() async {
    final me = await api.deleteAvatar();
    await store.saveMe(me);
    return me;
  }

  Future<UserProfile> changeEmail(String email, String password) async {
    final me = await api.changeEmail(email.trim(), password);
    await store.saveMe(me);
    return me;
  }

  Future<String> resendVerification() => api.resendVerification();

  /// Cierra la sesión: revoca el token en el servidor (si hay conexión),
  /// cancela las alarmas programadas y borra los datos locales.
  Future<void> logout() async {
    final refresh = tokens.refreshToken;
    if (refresh != null) {
      try {
        // Corto: al abrir la app sin «recordar sesión» se espera a esto.
        await api.logout(refresh).timeout(const Duration(seconds: 4));
      } on AppException catch (_) {
      } on TimeoutException catch (_) {}
    }
    await _wipe();
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    await _wipe();
  }

  Future<void> _wipe() async {
    await scheduler.stopAll();
    await tokens.clear();
    await store.clearAll();
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }
}
