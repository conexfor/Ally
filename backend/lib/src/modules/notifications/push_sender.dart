import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

class PushMessage {
  final String token;
  final String title;
  final String body;

  /// Datos para la app (FCM exige valores de tipo cadena).
  final Map<String, String> data;

  /// Mensaje solo de datos y prioridad alta: despierta la app para que
  /// sincronice y programe/cancele la alarma localmente.
  final bool dataOnly;

  const PushMessage({
    required this.token,
    required this.title,
    required this.body,
    this.data = const {},
    this.dataOnly = false,
  });
}

abstract interface class PushSender {
  /// Envía los mensajes y devuelve los tokens que ya no son válidos.
  Future<Set<String>> send(List<PushMessage> messages);
}

/// Sin credenciales de FCM: no envía nada (los clientes siguen recibiendo los
/// cambios al sincronizar).
class DisabledPushSender implements PushSender {
  @override
  Future<Set<String>> send(List<PushMessage> messages) async => const {};
}

/// Firebase Cloud Messaging (API HTTP v1) con una cuenta de servicio.
/// Sirve para Android y, configurando APNs en Firebase, también para iOS.
class FcmPushSender implements PushSender {
  final String projectId;
  final ServiceAccountCredentials _credentials;
  AutoRefreshingAuthClient? _client;
  final _log = Logger('FcmPushSender');

  FcmPushSender({required String serviceAccountJson, String? projectId})
      : _credentials = ServiceAccountCredentials.fromJson(serviceAccountJson),
        projectId = projectId ??
            (jsonDecode(serviceAccountJson) as Map<String, dynamic>)['project_id'] as String;

  Future<http.Client> _authClient() async => _client ??= await clientViaServiceAccount(
        _credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );

  @override
  Future<Set<String>> send(List<PushMessage> messages) async {
    if (messages.isEmpty) return const {};
    final invalid = <String>{};
    final client = await _authClient();
    final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');
    await Future.wait(messages.map((m) async {
      final payload = {
        'message': {
          'token': m.token,
          'data': {...m.data, 'title': m.title, 'body': m.body},
          if (!m.dataOnly) 'notification': {'title': m.title, 'body': m.body},
          'android': {
            'priority': 'high',
            if (!m.dataOnly) 'notification': {'channel_id': 'ally_updates'},
          },
          'apns': {
            'headers': {'apns-priority': m.dataOnly ? '5' : '10'},
            'payload': {
              'aps': m.dataOnly ? {'content-available': 1} : {'sound': 'default'},
            },
          },
        },
      };
      try {
        final response = await client
            .post(url, headers: {'content-type': 'application/json'}, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 404 ||
            (response.statusCode == 400 && response.body.contains('INVALID_ARGUMENT') &&
                response.body.contains('registration token')) ||
            response.body.contains('UNREGISTERED')) {
          invalid.add(m.token);
        } else if (response.statusCode >= 300) {
          _log.warning('FCM respondió ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        _log.warning('Error enviando push: $e');
      }
    }));
    return invalid;
  }
}
