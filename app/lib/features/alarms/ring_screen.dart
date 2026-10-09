import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';
import '../../services/system_channel.dart';

/// Si la alarma abrió la app (estaba cerrada o en segundo plano al sonar),
/// al responder se vuelve a lo que había antes en vez de dejar Ally abierta.
/// Lo actualiza `AllyApp` al ver empezar a sonar una alarma.
abstract final class RingLaunch {
  static bool openedByAlarm = false;
}

/// Pantalla que se muestra mientras suena una alarma.
class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({super.key});

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends ConsumerState<RingScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Cuando ya no suena ninguna alarma: si fue la alarma la que abrió la
    // app, se vuelve a la pantalla anterior (bloqueo u otra app).
    ref.listenManual(ringingProvider.select((r) => r.value?.isEmpty ?? false), (_, empty) {
      if (empty && RingLaunch.openedByAlarm) {
        RingLaunch.openedByAlarm = false;
        SystemChannel.moveToBackground();
      }
    });
  }

  Future<void> _respond(RingingAlarm ringing, ResponseStatus response, {int? minutes}) async {
    setState(() => _busy = true);
    final services = ref.read(appServicesProvider);
    // Se detiene el sonido de inmediato, pase lo que pase con la red.
    await services.scheduler.stop(ringing.nativeId);
    try {
      final alarm = await services.store.alarm(ringing.alarmId);
      if (alarm != null) {
        await services.alarms.respond(alarm, ringing.occurrenceAt, response, snoozeMinutes: minutes);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _snoozeCustom(RingingAlarm ringing) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Posponer')),
          for (final m in const [5, 10, 15, 30, 60])
            ListTile(title: Text(SpanishFormatter.duration(m)), onTap: () => Navigator.pop(context, m)),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Personalizado…'),
            onTap: () async {
              final minutes = await _askMinutes(context);
              if (context.mounted) Navigator.pop(context, minutes);
            },
          ),
        ]),
      ),
    );
    if (minutes != null) await _respond(ringing, ResponseStatus.snoozed, minutes: minutes);
  }

  /// Minutos escritos por el usuario (1 a 1440).
  static Future<int?> _askMinutes(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Posponer'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutos', suffixText: 'min'),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 1440 ? 'Entre 1 y 1440 minutos.' : null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, int.parse(controller.text));
            },
            child: const Text('Posponer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringing = ref.watch(ringingProvider).value ?? const [];
    final settings = ref.watch(settingsProvider).value ?? const UserSettings();
    final meId = ref.watch(meProvider).value?.id;
    final theme = Theme.of(context);
    if (ringing.isEmpty) return const Scaffold(body: LoadingView());
    final current = ringing.first;
    final alarm = ref.watch(alarmProvider(current.alarmId)).value;
    final now = TimeOfDay.now();

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: DefaultTextStyle(
          style: TextStyle(color: theme.colorScheme.onPrimary),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.alarm_rounded, size: 72, color: theme.colorScheme.onPrimary),
                const SizedBox(height: 16),
                Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(now),
                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onPrimary, fontSize: 64),
                ),
                const SizedBox(height: 12),
                Text(
                  alarm?.title ?? current.title.replaceFirst('⏰ ', ''),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimary),
                ),
                if ((alarm?.message ?? '').isNotEmpty && alarm!.message != alarm.title) ...[
                  const SizedBox(height: 8),
                  Text(alarm.message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                ],
                if (alarm != null && alarm.creator.id != meId) ...[
                  const SizedBox(height: 8),
                  Text('De ${alarm.creator.displayName}', style: const TextStyle(fontSize: 16)),
                ],
                if (ringing.length > 1) ...[
                  const SizedBox(height: 8),
                  Text('+${ringing.length - 1} alarma(s) más'),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.onPrimary,
                      foregroundColor: theme.colorScheme.primary,
                      minimumSize: const Size.fromHeight(60),
                    ),
                    onPressed: _busy ? null : () => _respond(current, ResponseStatus.confirmed),
                    child: const Text('Confirmar'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onPrimary,
                        side: BorderSide(color: theme.colorScheme.onPrimary.withValues(alpha: 0.6)),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _respond(current, ResponseStatus.snoozed, minutes: settings.defaultSnoozeMinutes),
                      onLongPress: _busy ? null : () => _snoozeCustom(current),
                      child: Text('Posponer ${settings.defaultSnoozeMinutes} min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onPrimary,
                        side: BorderSide(color: theme.colorScheme.onPrimary.withValues(alpha: 0.6)),
                      ),
                      onPressed: _busy ? null : () => _respond(current, ResponseStatus.dismissed),
                      child: const Text('Descartar'),
                    ),
                  ),
                ]),
                TextButton(
                  onPressed: _busy ? null : () => _snoozeCustom(current),
                  child: Text('Otro tiempo…', style: TextStyle(color: theme.colorScheme.onPrimary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
