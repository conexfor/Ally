import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../application/app_lock_controller.dart';
import '../../application/session_controller.dart';
import '../../application/voice_controller.dart';
import '../../core/config/env.dart';
import '../../core/widgets/common.dart';
import '../../services/voice_channel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const UserSettings();
    final services = ref.read(appServicesProvider);

    Future<void> save(UserSettings s) => runGuarded(context, () => services.auth.saveSettings(s));

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const SectionHeader('Alarmas'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.snooze_rounded),
                title: const Text('Posponer por defecto'),
                trailing: DropdownButton<int>(
                  value: const [5, 10, 15, 30].contains(settings.defaultSnoozeMinutes)
                      ? settings.defaultSnoozeMinutes
                      : 10,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final m in const [5, 10, 15, 30])
                      DropdownMenuItem(value: m, child: Text(SpanishFormatter.duration(m))),
                  ],
                  onChanged: (m) => m == null ? null : save(settings.copyWith(defaultSnoozeMinutes: m)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.alarm_on_rounded),
                title: const Text('Permisos de alarmas'),
                subtitle: const Text('Notificaciones, alarmas exactas y pantalla completa'),
                onTap: () async {
                  final ok = await services.notifications.requestPermissions();
                  final exact = await services.notifications.canScheduleExactAlarms();
                  if (context.mounted) {
                    showMessage(
                      context,
                      ok && exact
                          ? 'Permisos concedidos. Tus alarmas sonarán a tiempo.'
                          : 'Faltan permisos: actívalos en los ajustes del sistema para que las alarmas suenen.',
                    );
                  }
                  await services.scheduler.reschedule();
                },
              ),
            ]),
          ),
          const SectionHeader('Notificaciones'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.alarm_add_rounded),
                title: const Text('Nuevas alarmas recibidas'),
                value: settings.notifyNewAlarms,
                onChanged: (v) => save(settings.copyWith(notifyNewAlarms: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.task_alt_rounded),
                title: const Text('Respuestas a mis alarmas'),
                subtitle: const Text('Cuando alguien confirma o pospone'),
                value: settings.notifyResponses,
                onChanged: (v) => save(settings.copyWith(notifyResponses: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.person_add_alt_rounded),
                title: const Text('Solicitudes e invitaciones'),
                value: settings.notifyConnectionRequests,
                onChanged: (v) => save(settings.copyWith(notifyConnectionRequests: v)),
              ),
            ]),
          ),
          if (VoiceChannel.isSupported) ...[
            const SectionHeader('Asistente por voz'),
            const AppCard(padding: EdgeInsets.symmetric(vertical: 6), child: _WakeWordTile()),
          ],
          if (ref.watch(biometricsAvailableProvider).value ?? false) ...[
            const SectionHeader('Seguridad'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded),
                title: const Text('Bloquear con huella'),
                subtitle: const Text('Se pide al abrir la app y al volver tras 30 segundos. '
                    'Las alarmas que suenan se pueden atender sin desbloquear.'),
                value: ref.watch(appLockProvider).enabled,
                onChanged: (v) async {
                  final ok = await ref.read(appLockProvider.notifier).setEnabled(v);
                  if (context.mounted) {
                    showMessage(
                      context,
                      ok
                          ? (v ? 'Bloqueo con huella activado.' : 'Bloqueo con huella desactivado.')
                          : 'No se pudo verificar tu huella.',
                    );
                  }
                },
              ),
            ),
          ],
          const SectionHeader('Privacidad'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Solo tus contactos pueden enviarte alarmas y únicamente si se lo permites. '
              'Puedes elegir, por cada contacto, si sus alarmas se aceptan automáticamente y si '
              'puede ver tus respuestas. Configúralo desde Personas → contacto → Permisos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Política de privacidad'),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => openExternal(context, '${Env.publicWebUrl}/privacy'),
            ),
          ),
          const SectionHeader('Cuenta'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.alternate_email_rounded),
                title: const Text('Cambiar correo'),
                subtitle: Text(ref.watch(meProvider).value?.email ?? ''),
                onTap: () => _changeEmail(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Cambiar contraseña'),
                onTap: () => _changePassword(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.devices_other_rounded),
                title: const Text('Cerrar sesión en todos los dispositivos'),
                onTap: () async {
                  final ok = await confirmDialog(context,
                      title: 'Cerrar todas las sesiones',
                      message: 'Tendrás que volver a iniciar sesión en cada dispositivo.');
                  if (!ok || !context.mounted) return;
                  await runGuarded(context, () => services.api.client.post('/api/me/logout-all'));
                  await ref.read(sessionProvider.notifier).logout();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
                title: Text('Eliminar mi cuenta', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: const Text('Se borrarán tu perfil, tus alarmas y tus grupos.'),
                onTap: () async {
                  final ok = await confirmDialog(context,
                      title: 'Eliminar cuenta',
                      message: 'Esta acción no se puede deshacer. Se eliminarán todos tus datos.',
                      confirm: 'Eliminar definitivamente',
                      destructive: true);
                  if (!ok || !context.mounted) return;
                  await runGuarded(context, () => ref.read(sessionProvider.notifier).deleteAccount());
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar correo'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Nuevo correo'),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña actual',
                helperText: 'Si entraste con Google, déjala vacía.',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final user = await runGuarded(
      context,
      () => ref.read(appServicesProvider).auth.changeEmail(email.text, password.text),
      success: 'Correo actualizado. Te enviamos un enlace para confirmarlo.',
    );
    if (user != null) ref.read(sessionProvider.notifier).updateUser(user);
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              validator: Validators.password,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(appServicesProvider).auth.changePassword(current.text, next.text),
      success: 'Contraseña actualizada.',
    );
  }
}

/// Interruptor de «Hey Ally» y permiso de la burbuja flotante (solo Android).
class _WakeWordTile extends ConsumerStatefulWidget {
  const _WakeWordTile();

  @override
  ConsumerState<_WakeWordTile> createState() => _WakeWordTileState();
}

class _WakeWordTileState extends ConsumerState<_WakeWordTile> {
  // Al volver de los ajustes del sistema se vuelve a consultar el estado.
  late final _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(voiceWakeProvider));

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(voiceWakeProvider).value ?? const VoiceStatus();
    final available = status.modelAvailable && status.recognitionAvailable;
    final subtitle = !status.modelAvailable
        ? 'Esta versión de la app no incluye el modelo de la palabra clave.'
        : !status.recognitionAvailable
            ? 'Este teléfono no tiene reconocimiento de voz.'
            : status.enabled && !status.running
                ? 'Activado, pero ahora no está escuchando. Toca el interruptor dos veces para '
                    'reactivarlo, o revisa el permiso de micrófono.'
                : 'Di «Hey Ally» y luego, por ejemplo, «alarma a las 4 de la tarde con Ana, '
                    'Luis y Pedro». La alarma se crea directamente. Mientras escucha verás una '
                    'notificación fija y se usa algo más de batería.';
    return Column(children: [
      SwitchListTile(
        secondary: const Icon(Icons.record_voice_over_rounded),
        title: const Text('Activar con «Hey Ally»'),
        subtitle: Text(subtitle),
        isThreeLine: true,
        value: status.enabled && available,
        onChanged: !available
            ? null
            : (v) async {
                final result = await ref.read(voiceWakeProvider.notifier).setEnabled(v);
                if (!context.mounted) return;
                if (v && !result.micPermission) {
                  showMessage(context, 'Necesito permiso de micrófono para escucharte.');
                } else if (v) {
                  showMessage(context, 'Listo. Di «Hey Ally» cuando quieras.');
                }
              },
      ),
      if (status.enabled && !status.overlayPermission)
        ListTile(
          leading: const Icon(Icons.bubble_chart_outlined),
          title: const Text('Burbuja «Te escucho»'),
          subtitle: const Text('Permite «Mostrar sobre otras apps» para ver una burbuja animada '
              'en lugar de una notificación.'),
          trailing: TextButton(
            onPressed: VoiceChannel.requestOverlayPermission,
            child: const Text('Permitir'),
          ),
        ),
    ]);
  }
}
