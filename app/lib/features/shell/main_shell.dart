import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';

/// Ramas del shell (mismo orden que en el router).
abstract final class ShellTab {
  static const home = 0;
  static const alarms = 1;
  static const received = 2;
  static const assistant = 3;
  static const profile = 4;
}

/// Navegación inferior: Hoy · Alarmas · Crear · Recibidas · Perfil.
/// Historial y Personas se abren (apiladas) desde el perfil.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final invitations = (ref.watch(alarmsProvider).value ?? const <Alarm>[])
        .where((a) => me != null && a.recipientFor(me.id)?.permissionStatus == PermissionStatus.pending)
        .length;
    final contactRequests =
        (ref.watch(contactsProvider).value ?? const <Contact>[]).where((c) => c.isPendingIncoming).length;

    return Scaffold(
      body: _SectionEntrance(index: shell.currentIndex, child: shell),
      bottomNavigationBar: _BottomNav(
        current: shell.currentIndex,
        onSelect: _go,
        invitations: invitations,
        profileBadge: contactRequests,
      ),
    );
  }
}

/// Entrada suave al cambiar de sección. No cambia la estructura del árbol,
/// así cada pestaña conserva su estado.
class _SectionEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  const _SectionEntrance({required this.index, required this.child});

  @override
  State<_SectionEntrance> createState() => _SectionEntranceState();
}

class _SectionEntranceState extends State<_SectionEntrance> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(_SectionEntrance old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  final int invitations;
  final int profileBadge;

  const _BottomNav({
    required this.current,
    required this.onSelect,
    required this.invitations,
    required this.profileBadge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _NavItem(
              icon: Icons.wb_twilight_rounded,
              label: 'Hoy',
              active: current == ShellTab.home,
              onTap: () => onSelect(ShellTab.home),
            ),
            _NavItem(
              icon: Icons.access_time_rounded,
              label: 'Alarmas',
              active: current == ShellTab.alarms,
              onTap: () => onSelect(ShellTab.alarms),
            ),
            Expanded(
              child: _CreateButton(
                active: current == ShellTab.assistant,
                onTap: () => onSelect(ShellTab.assistant),
              ),
            ),
            _NavItem(
              icon: Icons.move_to_inbox_outlined,
              label: 'Recibidas',
              active: current == ShellTab.received,
              badge: invitations,
              onTap: () => onSelect(ShellTab.received),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Perfil',
              active: current == ShellTab.profile,
              badge: profileBadge,
              onTap: () => onSelect(ShellTab.profile),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.onSurface : scheme.outline;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AppTheme.violet,
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color),
            ),
            const SizedBox(height: 3),
            // Punto cyan de la sección activa.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 5 : 0,
              height: 5,
              decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Acción central: cuadrado oscuro rotado y elevado; violeta y girado cuando
/// la sección de creación está activa.
class _CreateButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _CreateButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? AppTheme.violet : scheme.primary;
    final turns = active ? 0.25 : 0.125;
    return Semantics(
      button: true,
      selected: active,
      label: 'Crear',
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -14),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedRotation(
              turns: turns,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                // El icono se contrarrota para quedar siempre recto.
                child: AnimatedRotation(
                  turns: -turns,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  child: Icon(Icons.add_rounded, color: active ? Colors.white : scheme.onPrimary, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
