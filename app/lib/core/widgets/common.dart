import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../errors/app_exception.dart';
import '../theme/app_theme.dart';

/// Avatar: la foto de perfil si existe y, mientras carga o si falla, las
/// iniciales.
class UserAvatar extends ConsumerWidget {
  final String name;
  final double size;
  final IconData? icon;

  /// Ruta de la foto en la API (`/api/users/<id>/avatar?v=...`).
  final String? imageUrl;

  const UserAvatar(this.name, {super.key, this.size = 44, this.icon, this.imageUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      final client = ref.watch(appServicesProvider).client;
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundImage: NetworkImage(client.absoluteUrl(url), headers: client.authHeaders),
        onForegroundImageError: (_, _) {},
        child: _initials(context),
      );
    }
    return _initials(context);
  }

  Widget _initials(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts.first[0] : '${parts.first[0]}${parts.last[0]}').toUpperCase();
    // Fondos cromáticos suaves con las iniciales en el color de identidad.
    const palette = [AppTheme.cyan, AppTheme.violet, AppTheme.orange, AppTheme.blue, AppTheme.green, AppTheme.pink];
    final accent = palette[name.hashCode.abs() % palette.length];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = Color.lerp(accent, dark ? Colors.white : Colors.black, 0.25)!;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Color.alphaBlend(accent.withValues(alpha: dark ? 0.28 : 0.16), scheme.surface),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: fg)
          : Text(
              initials,
              style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: fg, letterSpacing: -0.2),
            ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ?trailing,
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 18),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView(this.error, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Algo salió mal',
        message: userMessage(error),
        action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      );
}

/// Muestra un [AsyncValue] con estados de carga y error uniformes.
class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry});

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e, onRetry: onRetry),
      );
}

/// Indicador de respuesta de un destinatario (🟢 confirmada, 🟡 pospuesta...).
class ResponseBadge extends StatelessWidget {
  final ResponseStatus status;
  final PermissionStatus? permission;
  const ResponseBadge(this.status, {super.key, this.permission});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = permission == PermissionStatus.pending
        ? ('Pendiente de aceptar', scheme.outline)
        : permission == PermissionStatus.rejected
            ? ('Rechazada', AppTheme.danger)
            : switch (status) {
                ResponseStatus.confirmed => ('Confirmada', AppTheme.success),
                ResponseStatus.snoozed => ('Pospuesta', AppTheme.warning),
                ResponseStatus.dismissed => ('Descartada', scheme.error),
                ResponseStatus.expired => ('Expirada', scheme.outline),
                ResponseStatus.noResponse => ('Sin respuesta', scheme.outline),
              };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class PriorityChip extends StatelessWidget {
  final AlarmPriority priority;
  const PriorityChip(this.priority, {super.key});

  @override
  Widget build(BuildContext context) {
    if (priority == AlarmPriority.normal) return const SizedBox.shrink();
    final urgent = priority == AlarmPriority.urgent;
    final color = urgent ? AppTheme.danger : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(
        urgent ? 'Urgente' : 'Importante',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Muestra un mensaje breve (nunca errores técnicos).
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Notificación flotante con icono tras crear, completar o confirmar.
void showToast(BuildContext context, String message, {IconData icon = Icons.check_circle_rounded}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 2400),
      content: Row(children: [
        Icon(icon, color: AppTheme.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: scheme.onInverseSurface))),
      ]),
    ));
}

void showError(BuildContext context, Object error) => showMessage(context, userMessage(error));

/// Ejecuta una acción mostrando el error como mensaje si falla.
Future<T?> runGuarded<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  try {
    final result = await action();
    if (success != null && context.mounted) showMessage(context, success);
    return result;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirmar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppTheme.danger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Tarjeta con esquinas redondeadas y relleno uniforme.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) => Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// Abre un enlace en el navegador del sistema.
Future<void> openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMessage(context, 'No se pudo abrir el enlace.');
}

/// Selector de hora con AM/PM, como se muestran las horas en el resto de la
/// app. Con `es` Flutter usa un reloj de 24 h y tocar el "4" guardaba las
/// 04:00 aunque se quisiera decir las 4 de la tarde.
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) => showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) =>
          Localizations.override(context: context, locale: const Locale('es', 'US'), child: child),
    );
