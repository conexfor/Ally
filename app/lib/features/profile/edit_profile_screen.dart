import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../application/session_controller.dart';
import '../../core/widgets/common.dart';
import '../../services/device_service.dart';
import '../auth/auth_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  String _timezone = 'UTC';
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final me = ref.read(meProvider).value;
    if (me != null) {
      _name.text = me.displayName;
      _username.text = me.username;
      _phone.text = me.phone ?? '';
      _timezone = me.timezone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final user = await ref.read(appServicesProvider).auth.updateProfile({
        'display_name': _name.text.trim(),
        'username': Validators.normalizeUsername(_username.text),
        'phone': _phone.text.trim(),
        'timezone': _timezone,
      });
      ref.read(sessionProvider.notifier).updateUser(user);
      if (mounted) {
        showMessage(context, 'Perfil actualizado.');
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e);
      _form.currentState!.validate();
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _PhotoPicker(onChanged: (user) => ref.read(sessionProvider.notifier).updateUser(user)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => fieldError(_error, 'display_name') ?? Validators.displayName(v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Usuario', prefixText: '@'),
              validator: (v) => fieldError(_error, 'username') ?? Validators.username(v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                helperText: 'Permite que tus conocidos te encuentren por número.',
              ),
              validator: (v) => fieldError(_error, 'phone') ?? Validators.optionalPhone(v),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zona horaria'),
              subtitle: Text(_timezone),
              trailing: TextButton(
                onPressed: () async {
                  final tz = await DeviceService.currentTimezone();
                  setState(() => _timezone = tz);
                },
                child: const Text('Usar la del teléfono'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}

/// Foto de perfil: elegir de la galería o tomar con la cámara (se reduce a
/// 512 px antes de subirla) o quitarla.
class _PhotoPicker extends ConsumerStatefulWidget {
  final void Function(UserProfile user) onChanged;
  const _PhotoPicker({required this.onChanged});

  @override
  ConsumerState<_PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends ConsumerState<_PhotoPicker> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    final user = await runGuarded(
      context,
      () async => ref.read(appServicesProvider).auth.uploadAvatar(await file.readAsBytes()),
      success: 'Foto actualizada.',
    );
    if (user != null) widget.onChanged(user);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final user = await runGuarded(context, () => ref.read(appServicesProvider).auth.removeAvatar());
    if (user != null) widget.onChanged(user);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        UserAvatar(me?.displayName ?? '', size: 96, imageUrl: me?.avatarUrl),
        if (_busy) const SizedBox(width: 96, height: 96, child: CircularProgressIndicator()),
      ]),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
        TextButton.icon(
          onPressed: _busy ? null : () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Galería'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : () => _pick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Cámara'),
        ),
        if (me?.avatarUrl != null)
          TextButton(onPressed: _busy ? null : _remove, child: const Text('Quitar')),
      ]),
    ]);
  }
}
