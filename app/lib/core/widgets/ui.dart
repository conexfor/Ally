import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/alarm_format.dart';
import 'common.dart';

/// Limita el ancho del contenido.
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PageBody({super.key, required this.child, this.maxWidth = 1180});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// Avatares superpuestos con contador del resto (+2).
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final double size;
  final int max;
  final Color? ringColor;
  const AvatarStack(this.names, {super.key, this.size = 30, this.max = 4, this.ringColor});

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final ring = ringColor ?? scheme.surface;
    final count = shown.length + (extra > 0 ? 1 : 0);
    Widget ringed(Widget child) => Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
          child: child,
        );
    return Semantics(
      label: names.join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: size + 3,
        width: (size * 0.68) * (count - 1) + size + 3,
        child: Stack(children: [
          for (final (i, name) in shown.indexed)
            Positioned(left: i * size * 0.68, child: ringed(UserAvatar(name, size: size))),
          if (extra > 0)
            Positioned(
              left: shown.length * size * 0.68,
              child: ringed(CircleAvatar(
                radius: size / 2,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text('+$extra',
                    style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
              )),
            ),
        ]),
      ),
    );
  }
}

/// Texto con la cuenta regresiva hasta [target]; se actualiza solo.
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  const CountdownText(this.target, {super.key, this.style});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(AlarmFormat.countdown(widget.target), style: widget.style);
}

/// Bloque con título usado en formularios.
class BlockCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const BlockCard({super.key, required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ?trailing,
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// En pantallas grandes la app conserva el ancho de un smartphone y se
/// presenta centrada como un dispositivo; en móvil no hace nada.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});

  static const _width = 420.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < 600) return child;
    final height = (media.size.height - 48).clamp(560.0, 920.0);
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF050507) : const Color(0xFFE9EBEF),
      child: Center(
        child: Container(
          width: _width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 60, offset: const Offset(0, 24)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: MediaQuery(
              data: media.copyWith(
                size: Size(_width, height),
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                viewPadding: const EdgeInsets.only(top: 12, bottom: 8),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantallas de poca altura: se reducen tamaños y espacios.
bool isShortScreen(BuildContext context) => MediaQuery.sizeOf(context).height < 700;
