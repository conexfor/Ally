import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/utils/alarm_format.dart';
import '../../core/widgets/common.dart';

final myDevicesProvider = FutureProvider<List<Device>>((ref) => ref.watch(appServicesProvider).api.devices());

final currentDeviceProvider = FutureProvider<Device?>((ref) => ref.watch(appServicesProvider).store.device());

final devicePreferencesProvider = FutureProvider<Map<String, Map<String, bool>>>(
  (ref) => ref.watch(appServicesProvider).store.devicePreferences(),
);

IconData deviceIcon(DeviceType type) => switch (type) {
      DeviceType.phone => Icons.smartphone_rounded,
      DeviceType.tablet => Icons.tablet_android_rounded,
      DeviceType.computer => Icons.computer_rounded,
      DeviceType.watch => Icons.watch_rounded,
    };

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(myDevicesProvider);
    final current = ref.watch(currentDeviceProvider).value;
    final services = ref.read(appServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos')),
      body: AsyncBody(
        value: devices,
        onRetry: () => ref.invalidate(myDevicesProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myDevicesProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Tus alarmas suenan en los dispositivos activados. Puedes elegir por alarma desde su detalle.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final d in list) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(deviceIcon(d.deviceType), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.deviceName, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              [
                                if (d.id == current?.id) 'Este dispositivo',
                                if (d.lastSeenAt != null) 'Activo: ${AlarmFormat.day(d.lastSeenAt!).toLowerCase()}',
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ]),
                        ),
                        Switch(
                          value: d.receivesAlarms,
                          onChanged: (v) async {
                            await runGuarded(context, () => services.devices.setReceivesAlarms(d, v));
                            ref.invalidate(myDevicesProvider);
                            await services.scheduler.reschedule();
                          },
                        ),
                      ]),
                      Row(children: [
                        if (d.id == current?.id)
                          TextButton(
                            onPressed: () => _rename(context, ref, d),
                            child: const Text('Cambiar nombre'),
                          )
                        else
                          TextButton(
                            onPressed: () async {
                              final ok = await confirmDialog(context,
                                  title: 'Desvincular', message: 'Se cerrará la sesión en "${d.deviceName}".',
                                  confirm: 'Desvincular', destructive: true);
                              if (!ok || !context.mounted) return;
                              await runGuarded(context, () => services.api.removeDevice(d.id));
                              ref.invalidate(myDevicesProvider);
                            },
                            child: const Text('Desvincular'),
                          ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Device device) async {
    final controller = TextEditingController(text: device.deviceName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre del dispositivo'),
        content: TextField(controller: controller, autofocus: true, maxLength: 60),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await runGuarded(context, () => ref.read(appServicesProvider).devices.rename(name));
    ref
      ..invalidate(myDevicesProvider)
      ..invalidate(currentDeviceProvider);
  }
}
