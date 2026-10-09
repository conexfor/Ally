import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/session_controller.dart';
import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/common.dart';

/// Logotipo de la app.
class BrandMark extends StatelessWidget {
  final double size;
  final bool onPrimary;
  const BrandMark({super.key, this.size = 64, this.onPrimary = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = onPrimary ? scheme.primary : scheme.onPrimary;
    final bg = onPrimary ? scheme.onPrimary : scheme.primary;
    // Cuadrado rotado, el mismo motivo que la acción central de crear.
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: 0.785398, // 45°
          child: Container(
            width: size * 0.74,
            height: size * 0.74,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.2)),
            child: Transform.rotate(
              angle: -0.785398,
              child: Icon(Icons.access_time_rounded, size: size * 0.42, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estructura común de las pantallas de acceso: mucho espacio negativo y el
/// formulario a pantalla completa.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 44)),
              const SizedBox(height: 28),
              Text(title, style: theme.textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 28),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Botones de Google y Apple (solo si están disponibles/configurados).
class SocialSignInButtons extends ConsumerStatefulWidget {
  /// Texto del botón de Google.
  final String googleLabel;
  const SocialSignInButtons({super.key, this.googleLabel = 'Continuar con Google'});

  @override
  ConsumerState<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  bool _busy = false;

  bool get _appleAvailable => !kIsWeb && Platform.isIOS;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on AppException catch (e) {
      if (e.code != 'canceled' && mounted) showError(context, e);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.googleSignInConfigured && !_appleAvailable) return const SizedBox.shrink();
    final session = ref.read(sessionProvider.notifier);
    final label = widget.googleLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('o', style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 18),
        if (Env.googleSignInConfigured)
          OutlinedButton(
            onPressed: _busy ? null : () => _run(session.loginWithGoogle),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const _GoogleLogo(),
              const SizedBox(width: 12),
              Text(label),
            ]),
          ),
        if (_appleAvailable) ...[
          if (Env.googleSignInConfigured) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(session.loginWithApple),
            icon: const Icon(Icons.apple_rounded),
            label: const Text('Continuar con Apple'),
          ),
        ],
      ],
    );
  }
}

/// "G" de Google con sus colores (sin depender de imágenes).
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (rect) => const SweepGradient(
          colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)],
        ).createShader(rect),
        child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}

/// Muestra los errores de validación del servidor junto a cada campo.
String? fieldError(Object? error, String field) =>
    error is AppException ? error.fields[field] : null;
