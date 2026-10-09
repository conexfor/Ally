import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/moment.dart';
import '../../core/widgets/ui.dart';

/// Presentación en tres ideas. Con [replay] se abre desde el perfil y al
/// terminar simplemente se cierra.
class OnboardingScreen extends ConsumerStatefulWidget {
  final bool replay;
  const OnboardingScreen({super.key, this.replay = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    ('Crea un momento', 'Una hora, una actividad. Así de simple.'),
    ('Hazlo compartido', 'Invita a quien tenga que estar.'),
    ('Todos a tiempo', 'Cada uno confirma y tú lo ves al instante.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _leave(String route) {
    if (widget.replay) {
      context.pop();
      return;
    }
    ref.read(sessionProvider.notifier).markOnboardingSeen();
    context.go(route);
  }

  void _next() => _controller.nextPage(duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == _pages.length - 1;
    final short = isShortScreen(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(children: [
            Row(children: [
              Eyebrow('Ally · ${_page + 1}/${_pages.length}'),
              const Spacer(),
              if (widget.replay)
                IconButton(tooltip: 'Cerrar', onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded))
              else
                TextButton(onPressed: () => _leave('/login'), child: const Text('Entrar')),
            ]),
            Expanded(
              flex: 6,
              child: Center(child: _Orbit(step: _page, size: short ? 230 : 290)),
            ),
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final (title, body) = _pages[i];
                  return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ]);
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? theme.colorScheme.onSurface : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: last ? () => _leave('/register') : _next,
                child: Text(last ? 'Empezar' : 'Siguiente'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Ilustración abstracta basada en la interfaz: una hora en el centro de
/// órbitas; en el paso 2 aparecen personas alrededor y en el 3 la hora se
/// convierte en una confirmación verde.
class _Orbit extends StatefulWidget {
  final int step;
  final double size;
  const _Orbit({required this.step, required this.size});

  @override
  State<_Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<_Orbit> with SingleTickerProviderStateMixin {
  late final _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);

  static const _people = [
    ('Nicolás Ruiz', -0.62, AppTheme.violet),
    ('Ana López', 0.10, AppTheme.orange),
    ('Marta Gil', 0.78, AppTheme.cyan),
    ('Leo Pardo', 1.62, AppTheme.pink),
  ];

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.size;
    final done = widget.step >= 2;
    final shared = widget.step >= 1;
    final ring = done ? AppTheme.green : theme.colorScheme.outlineVariant;

    Widget orbit(double factor, double alpha) => AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: s * factor,
          height: s * factor,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring.withValues(alpha: done ? alpha : 1), width: 1.2),
          ),
        );

    return ExcludeSemantics(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(alignment: Alignment.center, children: [
          orbit(1.0, 0.25),
          orbit(0.72, 0.45),
          // Nodo que recorre la órbita exterior.
          AnimatedBuilder(
            animation: _float,
            builder: (_, _) {
              final a = -math.pi / 2 + _float.value * math.pi / 3;
              return Transform.translate(
                offset: Offset(math.cos(a) * s / 2, math.sin(a) * s / 2),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: done ? AppTheme.green : AppTheme.cyan, shape: BoxShape.circle),
                ),
              );
            },
          ),
          // Centro: la hora o la confirmación.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(anim), child: child),
            ),
            child: done
                ? Container(
                    key: const ValueKey('done'),
                    width: s * 0.42,
                    height: s * 0.42,
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppTheme.green.withValues(alpha: 0.35), blurRadius: 30)],
                    ),
                    child: Icon(Icons.check_rounded, color: Colors.white, size: s * 0.22),
                  )
                : Container(
                    key: const ValueKey('time'),
                    constraints: BoxConstraints(maxWidth: s * 0.7),
                    padding: EdgeInsets.symmetric(horizontal: s * 0.07, vertical: s * 0.05),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      boxShadow: AppTheme.softShadow(context),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Eyebrow('Mañana', color: AppTheme.violet),
                      const SizedBox(height: 4),
                      FittedBox(child: BigTime(hour: 7, minute: 30, size: s * 0.17)),
                    ]),
                  ),
          ),
          // Personas alrededor (paso 2 y 3), con movimiento vertical sutil.
          for (final (i, (name, angle, color)) in _people.indexed)
            AnimatedBuilder(
              animation: _float,
              builder: (_, child) {
                final r = s * 0.36;
                final bob = math.sin((_float.value + i * 0.25) * math.pi) * 4;
                return Transform.translate(
                  offset: Offset(math.cos(angle * math.pi / 2 - math.pi / 4) * r,
                      math.sin(angle * math.pi / 2 - math.pi / 4) * r + bob),
                  child: child,
                );
              },
              child: AnimatedScale(
                scale: shared ? 1 : 0,
                duration: Duration(milliseconds: 380 + i * 70),
                curve: Curves.easeOutBack,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppTheme.green : theme.colorScheme.surface,
                    boxShadow: AppTheme.softShadow(context),
                  ),
                  child: Stack(clipBehavior: Clip.none, children: [
                    UserAvatar(name, size: s * 0.15),
                    if (!done)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.surface, width: 2),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
