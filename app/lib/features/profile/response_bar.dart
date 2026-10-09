import 'package:flutter/material.dart';

/// Segmento de la barra de reparto.
class ResponseShare {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const ResponseShare(this.label, this.value, this.color, this.icon);
}

/// Barra apilada horizontal (parte de un todo) con leyenda de valores.
///
/// - Separación de 2 px entre segmentos y extremos redondeados.
/// - La leyenda muestra icono + etiqueta + número + porcentaje en el color
///   del texto: la identidad nunca depende solo del color.
/// - Tocar un segmento muestra su detalle.
class ResponseBar extends StatelessWidget {
  final List<ResponseShare> shares;
  const ResponseBar({super.key, required this.shares});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = shares.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) {
      return Text('Aún no hay respuestas en este periodo.', style: theme.textTheme.bodyMedium);
    }
    final visible = shares.where((s) => s.value > 0).toList();
    String percent(int v) => '${(v * 100 / total).round()} %';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: [for (final s in shares) '${s.label}: ${s.value}'].join(', '),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 16,
              child: Row(children: [
                for (final (i, s) in visible.indexed) ...[
                  if (i > 0) SizedBox(width: 2, child: ColoredBox(color: theme.cardTheme.color ?? theme.colorScheme.surface)),
                  Expanded(
                    flex: s.value,
                    child: Tooltip(
                      message: '${s.label}: ${s.value} (${percent(s.value)})',
                      triggerMode: TooltipTriggerMode.tap,
                      child: ColoredBox(color: s.color),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final s in shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(s.icon, size: 18, color: s.color),
              const SizedBox(width: 8),
              Expanded(child: Text(s.label, style: theme.textTheme.bodyMedium)),
              Text('${s.value}', style: theme.textTheme.titleMedium),
              SizedBox(
                width: 56,
                child: Text(
                  percent(s.value),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
