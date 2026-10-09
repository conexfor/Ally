import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../theme/app_theme.dart';
import '../utils/alarm_format.dart';
import 'common.dart';

/// Color de identidad de un momento. No hay un campo en el modelo, así que
/// se deduce del contexto:
/// - verde: ya terminó o está confirmado por todos;
/// - rosa: afectivo (familia, cumpleaños…);
/// - naranja: encuentros sociales o presenciales;
/// - azul: rutinas y actividades recurrentes;
/// - violeta: colaboración (varias personas o grupos);
/// - cyan: momentos personales.
Color momentColor(Alarm alarm, String meId) {
  if (!alarm.isActive) return AppTheme.green;
  final text = TextNormalizer.nameKey('${alarm.title} ${alarm.message ?? ''}');
  bool has(List<String> words) => words.any((w) => RegExp('\\b$w').hasMatch(text));
  if (has(const ['mama', 'papa', 'abuel', 'cumple', 'aniversario', 'hij', 'familia', 'amor', 'novi', 'boda'])) {
    return AppTheme.pink;
  }
  if (has(const ['cena', 'comida', 'almuerzo', 'cafe', 'partido', 'fiesta', 'quedada', 'cine', 'bar', 'salida'])) {
    return AppTheme.orange;
  }
  if (alarm.repeat != null) return AppTheme.blue;
  final shared = alarm.recipients.any((r) => r.recipientType == RecipientType.group) ||
      AlarmFormat.participants(alarm).length > 1 ||
      alarm.creator.id != meId;
  return shared ? AppTheme.violet : AppTheme.cyan;
}

/// Estado social de un momento (texto breve + color de su punto).
({String label, Color color}) momentStatus(Alarm alarm, String meId) {
  if (alarm.status == AlarmStatus.cancelled || alarm.isDeleted) {
    return (label: 'Cancelada', color: AppTheme.danger);
  }
  if (!alarm.isActive || alarm.nextOccurrenceAt == null) return (label: 'Completada', color: AppTheme.green);
  if (alarm.recipientFor(meId)?.permissionStatus == PermissionStatus.pending) {
    return (label: 'Invitación pendiente', color: AppTheme.warning);
  }
  final people = alarm.recipients
      .where((r) => r.recipientType == RecipientType.user && r.permissionStatus != PermissionStatus.rejected)
      .toList();
  final confirmed = people.where((r) => r.responseStatus == ResponseStatus.confirmed).length;
  if (people.length <= 1) {
    return confirmed == 1
        ? (label: 'Confirmada', color: AppTheme.green)
        : (label: 'Programada', color: AppTheme.inkTertiary);
  }
  if (confirmed == people.length) {
    return (label: people.length == 2 ? 'Ambos confirmaron' : 'Todos confirmaron', color: AppTheme.green);
  }
  if (confirmed == 0) return (label: 'Por confirmar', color: AppTheme.warning);
  return (label: '$confirmed de ${people.length} confirmados', color: AppTheme.cyan);
}

/// Punto cromático con texto breve.
class StatusDot extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  const StatusDot(this.label, {super.key, required this.color, this.fontSize = 12});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ]);
}

/// Etiqueta de categoría en mayúsculas ("TU TIEMPO", "MAÑANA").
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppTheme.eyebrow(context, color: color));
}

/// Superficie blanca con borde fino y sombra suave.
class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Botón circular para completar un momento (confirma la próxima ocurrencia).
class CompleteButton extends ConsumerStatefulWidget {
  final Alarm alarm;
  final String meId;
  final Color color;
  final bool compact;
  const CompleteButton({super.key, required this.alarm, required this.meId, required this.color, this.compact = false});

  /// Solo puede completarlo quien recibe la alarma.
  static bool canComplete(Alarm alarm, String meId) =>
      alarm.isActive &&
      alarm.nextOccurrenceAt != null &&
      alarm.recipientFor(meId)?.permissionStatus == PermissionStatus.accepted;

  static bool isDone(Alarm alarm, String meId) =>
      alarm.recipientFor(meId)?.responseStatus == ResponseStatus.confirmed;

  /// Confirmar antes de la hora silencia esa ocurrencia en todos los
  /// dispositivos del usuario: se pide confirmación para evitar un toque
  /// accidental (p. ej. justo después de aceptar una invitación).
  static Future<bool> confirmBeforeRing(BuildContext context, DateTime next) async {
    if (!next.isAfter(DateTime.now())) return true;
    return confirmDialog(
      context,
      title: '¿Confirmar antes de la hora?',
      message: 'Si lo confirmas ahora, la alarma no sonará en tus dispositivos esta vez.',
      confirm: 'Confirmar',
    );
  }

  @override
  ConsumerState<CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends ConsumerState<CompleteButton> {
  bool _busy = false;

  Future<void> _complete() async {
    final next = widget.alarm.nextOccurrenceAt;
    if (next == null || _busy) return;
    if (!await CompleteButton.confirmBeforeRing(context, next) || !mounted) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(appServicesProvider).alarms.respond(widget.alarm, next, ResponseStatus.confirmed),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) showToast(context, 'Momento confirmado', icon: Icons.check_circle_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final done = CompleteButton.isDone(widget.alarm, widget.meId);
    final size = widget.compact ? 34.0 : 40.0;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: done ? 'Confirmado' : 'Completar',
      child: Semantics(
        button: true,
        label: done ? 'Confirmado' : 'Completar momento',
        child: GestureDetector(
          onTap: done ? null : _complete,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? widget.color : Colors.transparent,
              border: Border.all(color: done ? widget.color : scheme.outlineVariant, width: 1.6),
            ),
            child: _busy
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
                  )
                : Icon(Icons.check_rounded, size: size * 0.5, color: done ? Colors.white : scheme.outline),
          ),
        ),
      ),
    );
  }
}

/// El momento compartido aún espera confirmaciones de alguien.
bool awaitingConfirmation(Alarm alarm, String meId) {
  if (!alarm.isActive) return false;
  final people = alarm.recipients
      .where((r) => r.recipientType == RecipientType.user && r.permissionStatus != PermissionStatus.rejected)
      .toList();
  return people.length > 1 && people.any((r) => r.responseStatus != ResponseStatus.confirmed);
}

/// Hora como imagen tipográfica: "07:42" grande y "AM" pequeño al lado.
class BigTime extends StatelessWidget {
  final int hour;
  final int minute;
  final double size;
  final Color? color;
  const BigTime({super.key, required this.hour, required this.minute, required this.size, this.color});

  /// Hora local del dispositivo para un instante UTC.
  factory BigTime.of(DateTime utc, {required double size, Color? color}) {
    final l = utc.toLocal();
    return BigTime(hour: l.hour, minute: l.minute, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurface;
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final digits = '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return Semantics(
      label: '$digits ${hour < 12 ? 'AM' : 'PM'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(digits, style: AppTheme.time(size, color: fg)),
          SizedBox(width: size * 0.08),
          Text(
            hour < 12 ? 'AM' : 'PM',
            style: TextStyle(
              fontSize: (size * 0.26).clamp(11, 20),
              fontWeight: FontWeight.w600,
              color: fg.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
