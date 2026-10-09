import 'package:logging/logging.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

import '../../config/app_config.dart';

abstract interface class EmailSender {
  Future<void> send({required String to, required String subject, required String text});
}

class SmtpEmailSender implements EmailSender {
  final SmtpConfig config;
  final _log = Logger('SmtpEmailSender');

  SmtpEmailSender(this.config);

  @override
  Future<void> send({required String to, required String subject, required String text}) async {
    final server = SmtpServer(
      config.host,
      port: config.port,
      ssl: config.ssl,
      username: config.username,
      password: config.password,
    );
    final message = mailer.Message()
      ..from = mailer.Address(config.from, 'Ally')
      ..recipients.add(to)
      ..subject = subject
      ..text = text;
    try {
      await mailer.send(message, server, timeout: const Duration(seconds: 20));
    } catch (e) {
      // Un fallo de correo no debe romper el flujo (ni revelar si la cuenta existe).
      _log.warning('No se pudo enviar el correo a $to: $e');
    }
  }
}

/// Usado cuando no hay SMTP configurado (desarrollo): escribe el correo en el
/// log para poder copiar el enlace.
class LogEmailSender implements EmailSender {
  final _log = Logger('LogEmailSender');

  @override
  Future<void> send({required String to, required String subject, required String text}) async {
    _log.info('Correo para $to — $subject\n$text');
  }
}
