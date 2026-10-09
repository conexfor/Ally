import '../domain/enums.dart';
import 'json.dart';
import 'user_dtos.dart';

/// Lo que un usuario permite a otro respecto de las alarmas.
class ConnectionPermissions {
  /// Puede enviarme alarmas.
  final bool allowAlarms;

  /// Sus alarmas se aceptan automáticamente (sin pedir confirmación).
  final bool autoAccept;

  /// Puede ver si confirmé, pospuse o ignoré sus alarmas.
  final bool shareResponseStatus;

  const ConnectionPermissions({
    this.allowAlarms = true,
    this.autoAccept = false,
    this.shareResponseStatus = true,
  });

  factory ConnectionPermissions.fromJson(JsonMap json) => ConnectionPermissions(
        allowAlarms: json['allow_alarms'] as bool? ?? true,
        autoAccept: json['auto_accept'] as bool? ?? false,
        shareResponseStatus: json['share_response_status'] as bool? ?? true,
      );

  JsonMap toJson() => {
        'allow_alarms': allowAlarms,
        'auto_accept': autoAccept,
        'share_response_status': shareResponseStatus,
      };

  ConnectionPermissions copyWith({
    bool? allowAlarms,
    bool? autoAccept,
    bool? shareResponseStatus,
  }) =>
      ConnectionPermissions(
        allowAlarms: allowAlarms ?? this.allowAlarms,
        autoAccept: autoAccept ?? this.autoAccept,
        shareResponseStatus: shareResponseStatus ?? this.shareResponseStatus,
      );
}

enum ConnectionDirection {
  incoming('incoming'),
  outgoing('outgoing');

  const ConnectionDirection(this.wire);
  final String wire;
  static ConnectionDirection fromWire(String w) =>
      values.firstWhere((v) => v.wire == w);
}

/// Conexión con otro usuario, vista desde el usuario autenticado.
class Contact {
  final String connectionId;
  final ConnectionStatus status;
  final ConnectionDirection direction;
  final PublicUser user;

  /// Lo que yo le permito a este contacto.
  final ConnectionPermissions grantedByMe;

  /// Lo que este contacto me permite a mí (solo lectura).
  final ConnectionPermissions grantedToMe;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Contact({
    required this.connectionId,
    required this.status,
    required this.direction,
    required this.user,
    required this.grantedByMe,
    required this.grantedToMe,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAccepted => status == ConnectionStatus.accepted;
  bool get isPendingIncoming =>
      status == ConnectionStatus.pending &&
      direction == ConnectionDirection.incoming;

  factory Contact.fromJson(JsonMap json) => Contact(
        connectionId: json['connection_id'] as String,
        status: ConnectionStatus.fromWire(json['status'] as String),
        direction: ConnectionDirection.fromWire(json['direction'] as String),
        user: PublicUser.fromJson(json['user'] as JsonMap),
        grantedByMe: ConnectionPermissions.fromJson(
            json['granted_by_me'] as JsonMap? ?? const {}),
        grantedToMe: ConnectionPermissions.fromJson(
            json['granted_to_me'] as JsonMap? ?? const {}),
        createdAt: parseRequiredDateTime(json['created_at']),
        updatedAt: parseRequiredDateTime(json['updated_at']),
      );

  JsonMap toJson() => {
        'connection_id': connectionId,
        'status': status.wire,
        'direction': direction.wire,
        'user': user.toJson(),
        'granted_by_me': grantedByMe.toJson(),
        'granted_to_me': grantedToMe.toJson(),
        'created_at': formatDateTime(createdAt),
        'updated_at': formatDateTime(updatedAt),
      };
}

/// Código de invitación (se muestra como texto y como QR).
class InvitationCode {
  final String code;
  final DateTime expiresAt;

  /// Contenido del QR: `ally://connect?code=XXXX`.
  String get qrPayload => 'ally://connect?code=$code';

  const InvitationCode({required this.code, required this.expiresAt});

  /// Extrae el código de un QR o de un texto escrito por el usuario.
  static String? parsePayload(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    if (uri != null && uri.scheme == 'ally') {
      return uri.queryParameters['code']?.toUpperCase();
    }
    final plain = text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^[A-Z0-9]{6,12}$').hasMatch(plain) ? plain : null;
  }

  factory InvitationCode.fromJson(JsonMap json) => InvitationCode(
        code: json['code'] as String,
        expiresAt: parseRequiredDateTime(json['expires_at']),
      );

  JsonMap toJson() => {
        'code': code,
        'expires_at': formatDateTime(expiresAt),
        'qr_payload': qrPayload,
      };
}
