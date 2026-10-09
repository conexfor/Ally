import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../core/errors/app_exception.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _sent;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref.read(appServicesProvider).auth.forgotPassword(_email.text);
      setState(() => _sent = message);
    } catch (e) {
      setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      title: 'Recupera tu contraseña',
      subtitle: 'Te enviaremos un enlace para crear una nueva.',
      children: [
        if (_sent != null) ...[
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.mark_email_read_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(_sent!)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => context.go('/login'), child: const Text('Volver a iniciar sesión')),
        ] else ...[
          Form(
            key: _form,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: Validators.email,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Text('Enviar enlace'),
          ),
        ],
      ],
    );
  }
}
