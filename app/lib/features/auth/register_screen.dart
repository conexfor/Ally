import 'package:flutter/material.dart';

import 'login_screen.dart';

/// `/register` abre la misma superficie de acceso en modo registro.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) => const LoginScreen(startInRegister: true);
}
