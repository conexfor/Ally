import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/app_lock_controller.dart';
import '../../application/session_controller.dart';
import 'auth_widgets.dart';
import 'splash_screen.dart';

/// Envuelve toda la app: si el bloqueo con huella está activo, cubre el
/// contenido hasta que el usuario se autentica.
///
/// Excepción: una alarma sonando nunca queda bloqueada (se puede posponer o
/// confirmar sin desbloquear, como en el reloj del sistema).
class AppLockGate extends ConsumerWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final ringing = (ref.watch(ringingProvider).value ?? const []).isNotEmpty;
    final signedIn = ref.watch(sessionProvider) is SignedIn;
    final covered = signedIn && !ringing && (!lock.loaded || lock.locked);
    return Stack(children: [
      // El contenido sigue montado (no se pierde el estado) pero no es visible
      // ni interactivo mientras está bloqueado.
      Offstage(offstage: covered, child: child),
      // Mientras se lee la preferencia sigue la misma pantalla de carga.
      if (covered) lock.loaded ? const _LockScreen() : const SplashView(),
    ]);
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  @override
  void initState() {
    super.initState();
    // Pide la huella automáticamente al mostrarse.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() => ref.read(appLockProvider.notifier).unlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(meProvider).value;
    return Material(
      color: theme.colorScheme.primary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            const Spacer(),
            const BrandMark(size: 80, onPrimary: true),
            const SizedBox(height: 24),
            Text(
              'Ally está bloqueada',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimary),
            ),
            if (me != null) ...[
              const SizedBox(height: 8),
              Text(me.displayName, style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.85))),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onPrimary,
                  foregroundColor: theme.colorScheme.primary,
                ),
                onPressed: _unlock,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Desbloquear'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
              child: Text('Cerrar sesión', style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ]),
        ),
      ),
    );
  }
}
