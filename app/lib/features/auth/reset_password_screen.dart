import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/common.dart';
import 'auth_widgets.dart';

/// Se abre desde el enlace del correo (`ally://reset-password?token=`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref.read(appServicesProvider).auth.resetPassword(widget.token, _password.text);
      if (!mounted) return;
      showMessage(context, message);
      context.go('/login');
    } catch (e) {
      setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token.isEmpty) {
      return const AuthScaffold(title: 'Enlace no válido', children: [
        Text('Abre el enlace que recibiste por correo o solicita uno nuevo.'),
      ]);
    }
    return AuthScaffold(
      title: 'Nueva contraseña',
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repite la contraseña'),
              validator: (v) => v != _password.text ? 'Las contraseñas no coinciden.' : null,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
        ],
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Guardar contraseña')),
      ],
    );
  }
}
