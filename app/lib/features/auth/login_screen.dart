import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ally_core/ally_core.dart';

import '../../app/providers.dart';
import '../../application/session_controller.dart';
import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/common.dart';
import 'auth_widgets.dart';

/// Acceso y registro en la misma superficie: cambiar de modo no navega, solo
/// transforma el formulario.
class LoginScreen extends ConsumerStatefulWidget {
  final bool startInRegister;
  const LoginScreen({super.key, this.startInRegister = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  late bool _register = widget.startInRegister;
  bool _busy = false;
  bool _obscure = true;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggle() => setState(() {
        _register = !_register;
        _error = null;
        _form.currentState?.reset();
      });

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final session = ref.read(sessionProvider.notifier);
    try {
      if (_register) {
        await session.register(
          email: _identifier.text,
          password: _password.text,
          username: await _availableUsername(),
          displayName: _name.text.trim(),
        );
      } else {
        await session.login(_identifier.text, _password.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// El nombre de usuario se genera a partir del correo (se puede cambiar
  /// después en el perfil). Si está ocupado se añade un número.
  Future<String> _availableUsername() async {
    final api = ref.read(appServicesProvider).api;
    final local = Validators.normalizeEmail(_identifier.text).split('@').first;
    var base = local.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (base.length < 3) base = '${base}ally';
    if (base.length > 24) base = base.substring(0, 24);
    final random = math.Random();
    for (var attempt = 0; attempt < 6; attempt++) {
      final candidate = attempt == 0 ? base : '$base${random.nextInt(9000) + 100}';
      try {
        if (await api.usernameAvailable(candidate)) return candidate;
      } catch (_) {
        // Sin respuesta: el servidor validará al registrar.
        return candidate;
      }
    }
    return '$base${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generalError = _error != null && (_error is! AppException || (_error as AppException).fields.isEmpty);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 44)),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(_register),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_register ? 'Crea tu espacio' : 'Bienvenido de nuevo', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    _register ? 'Tu tiempo, compartido con quien importa.' : 'Entra para ver tus momentos.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: _register
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(hintText: 'Nombre'),
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              validator: (v) => fieldError(_error, 'display_name') ?? Validators.displayName(v),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  TextFormField(
                    controller: _identifier,
                    decoration: InputDecoration(hintText: _register ? 'Email' : 'Email o usuario'),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    validator: (v) => _register
                        ? fieldError(_error, 'email') ?? Validators.email(v)
                        : ((v ?? '').trim().isEmpty ? 'Escribe tu correo o usuario.' : null),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      helperText: _register ? 'Mínimo 8 caracteres, con letras y números.' : null,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => _register
                        ? fieldError(_error, 'password') ?? Validators.password(v)
                        : ((v ?? '').isEmpty ? 'Escribe tu contraseña.' : null),
                  ),
                ]),
              ),
            ),
            if (!_register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text('¿Olvidaste tu contraseña?',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ),
              )
            else
              const SizedBox(height: 16),
            if (generalError) ...[
              Text(userMessage(_error!), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.colorScheme.onPrimary),
                    )
                  : Text(_register ? 'Crear cuenta' : 'Iniciar sesión'),
            ),
            const SocialSignInButtons(),
            if (_register) ...[
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: theme.textTheme.bodySmall,
                  children: [
                    const TextSpan(text: 'Al crear la cuenta aceptas las condiciones de uso y la '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => openExternal(context, '${Env.publicWebUrl}/privacy'),
                        child: Text('Política de privacidad',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            )),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_register ? '¿Ya tienes cuenta?' : '¿Aún no tienes cuenta?',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                TextButton(onPressed: _toggle, child: Text(_register ? 'Inicia sesión' : 'Crea tu espacio')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
