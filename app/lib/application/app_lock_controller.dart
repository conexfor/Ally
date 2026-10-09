import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/biometric_service.dart';
import 'session_controller.dart';

class AppLockState {
  /// Ya se leyó la preferencia guardada.
  final bool loaded;

  /// El usuario activó el bloqueo con huella.
  final bool enabled;

  /// La app está bloqueada y espera la huella.
  final bool locked;

  const AppLockState({this.loaded = false, this.enabled = false, this.locked = false});

  AppLockState copyWith({bool? loaded, bool? enabled, bool? locked}) => AppLockState(
        loaded: loaded ?? this.loaded,
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
      );
}

/// Bloqueo de la app con huella:
/// - al abrirla con la sesión iniciada;
/// - al volver a ella tras [relockAfter] en segundo plano.
///
/// Se desactiva al cerrar sesión (otra persona que entre en el mismo teléfono
/// no hereda el bloqueo).
class AppLockController extends Notifier<AppLockState> {
  static const relockAfter = Duration(seconds: 30);

  final biometrics = BiometricService();
  AppLifecycleListener? _lifecycle;
  DateTime? _backgroundedAt;
  bool _authenticating = false;

  @override
  AppLockState build() {
    final signedIn = ref.watch(sessionProvider.select((s) => s is SignedIn));
    ref.onDispose(() => _lifecycle?.dispose());
    if (!signedIn) {
      // Al cerrar sesión se desactiva (no aplica al arrancar sin sesión).
      if (stateOrNull?.enabled ?? false) unawaited(biometrics.setEnabled(false));
      return const AppLockState(loaded: true);
    }
    _lifecycle ??= AppLifecycleListener(
      onHide: () => _backgroundedAt = DateTime.now(),
      onShow: _onShow,
    );
    unawaited(_load());
    return const AppLockState();
  }

  Future<void> _load() async {
    final enabled = await biometrics.isEnabled() && await biometrics.isAvailable();
    state = AppLockState(loaded: true, enabled: enabled, locked: enabled);
  }

  void _onShow() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    // Mientras se muestra el diálogo de huella la app también pasa por
    // segundo plano: no debe volver a bloquearse por eso.
    if (_authenticating || !state.enabled || since == null) return;
    if (DateTime.now().difference(since) >= relockAfter) state = state.copyWith(locked: true);
  }

  Future<bool> unlock() async {
    if (_authenticating) return false;
    _authenticating = true;
    try {
      final ok = await biometrics.authenticate('Desbloquea Ally');
      if (ok) state = state.copyWith(locked: false);
      return ok;
    } finally {
      _authenticating = false;
    }
  }

  /// Activa o desactiva el bloqueo; ambas cosas requieren la huella.
  /// Devuelve `false` si el usuario no se autenticó.
  Future<bool> setEnabled(bool enabled) async {
    _authenticating = true;
    try {
      final ok = await biometrics.authenticate(
        enabled ? 'Confirma tu huella para activar el bloqueo' : 'Confirma tu huella para desactivar el bloqueo',
      );
      if (!ok) return false;
      await biometrics.setEnabled(enabled);
      state = state.copyWith(enabled: enabled, locked: false);
      return true;
    } finally {
      _authenticating = false;
    }
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

/// ¿Hay biometría disponible en el dispositivo? (para mostrar la opción).
final biometricsAvailableProvider = FutureProvider<bool>(
  (ref) => ref.read(appLockProvider.notifier).biometrics.isAvailable(),
);
