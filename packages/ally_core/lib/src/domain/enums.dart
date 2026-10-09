/// Enumeraciones del dominio. Cada valor tiene un `wire` estable que se usa
/// en la API JSON y en la base de datos, independiente del nombre en Dart.
library;

T _byWire<T extends Enum>(List<T> values, String wire, String Function(T) of) =>
    values.firstWhere(
      (v) => of(v) == wire,
      orElse: () => throw FormatException('Valor desconocido: $wire'),
    );

enum AlarmStatus {
  scheduled('scheduled'),
  triggered('triggered'),
  completed('completed'),
  cancelled('cancelled'),
  snoozed('snoozed');

  const AlarmStatus(this.wire);
  final String wire;
  static AlarmStatus fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum AlarmPriority {
  normal('normal'),
  important('important'),
  urgent('urgent');

  const AlarmPriority(this.wire);
  final String wire;
  static AlarmPriority fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

/// Tipo de disparador. Solo `time` está implementado; los de ubicación
/// quedan modelados para versiones futuras.
enum TriggerType {
  time('time'),
  locationArrive('location_arrive'),
  locationLeave('location_leave');

  const TriggerType(this.wire);
  final String wire;
  static TriggerType fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum RecipientType {
  user('user'),
  group('group'),
  device('device');

  const RecipientType(this.wire);
  final String wire;
  static RecipientType fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

/// Si el destinatario aceptó recibir la alarma.
enum PermissionStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected');

  const PermissionStatus(this.wire);
  final String wire;
  static PermissionStatus fromWire(String w) =>
      _byWire(values, w, (v) => v.wire);
}

/// Respuesta de un destinatario a una alarma (o a una ocurrencia).
enum ResponseStatus {
  noResponse('no_response'),
  confirmed('confirmed'),
  dismissed('dismissed'),
  snoozed('snoozed'),
  expired('expired');

  const ResponseStatus(this.wire);
  final String wire;
  static ResponseStatus fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum ConnectionStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  blocked('blocked');

  const ConnectionStatus(this.wire);
  final String wire;
  static ConnectionStatus fromWire(String w) =>
      _byWire(values, w, (v) => v.wire);
}

enum GroupRole {
  owner('owner'),
  admin('admin'),
  member('member');

  const GroupRole(this.wire);
  final String wire;
  static GroupRole fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum DeviceType {
  phone('phone'),
  tablet('tablet'),
  computer('computer'),
  watch('watch');

  const DeviceType(this.wire);
  final String wire;
  static DeviceType fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum DevicePlatform {
  android('android'),
  ios('ios'),
  web('web'),
  other('other');

  const DevicePlatform(this.wire);
  final String wire;
  static DevicePlatform fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum RepeatFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  const RepeatFrequency(this.wire);
  final String wire;
  static RepeatFrequency fromWire(String w) =>
      _byWire(values, w, (v) => v.wire);
}

enum NotificationType {
  alarmNew('alarm_new'),
  alarmRequest('alarm_request'),
  alarmUpdated('alarm_updated'),
  alarmCancelled('alarm_cancelled'),
  alarmTriggered('alarm_triggered'),
  alarmConfirmed('alarm_confirmed'),
  alarmSnoozed('alarm_snoozed'),
  alarmDismissed('alarm_dismissed'),
  connectionRequest('connection_request'),
  connectionAccepted('connection_accepted'),
  groupInvitation('group_invitation'),
  syncRequired('sync_required');

  const NotificationType(this.wire);
  final String wire;
  static NotificationType fromWire(String w) =>
      _byWire(values, w, (v) => v.wire);
}

enum AuthProvider {
  password('password'),
  google('google'),
  apple('apple');

  const AuthProvider(this.wire);
  final String wire;
  static AuthProvider fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum ChatRole {
  user('user'),
  system('system');

  const ChatRole(this.wire);
  final String wire;
  static ChatRole fromWire(String w) => _byWire(values, w, (v) => v.wire);
}
