import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_widgets.dart';

/// Pantalla de arranque mientras se restaura la sesión. Tocarla lleva a la
/// presentación (si aún se está cargando, el router la mantiene aquí).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/onboarding'),
        child: const SplashView(),
      );
}

/// Contenido de la pantalla de carga: también lo usa [AppLockGate] mientras lee
/// la preferencia de bloqueo, para que el arranque se vea como una sola pantalla.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const BrandMark(size: 72),
            const SizedBox(height: 22),
            Text('Ally', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Tiempo compartido.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: theme.colorScheme.onSurface,
                  backgroundColor: theme.colorScheme.outlineVariant,
                  semanticsLabel: 'Cargando',
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
