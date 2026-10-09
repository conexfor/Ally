import 'package:ally_core/ally_core.dart';

import 'api_client.dart';

/// Endpoints de la API de Ally con tipos del contrato compartido.
class AllyApi {
  final ApiClient client;
  AllyApi(this.client);

  // ------------------------------------------------------------- autenticación

  Future<AuthSession> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required String timezone,
  }) async =>
      AuthSession.fromJson(await client.post('/api/auth/register', {
        'email': email,
        'password': password,
        'username': username,
        'display_name': displayName,
        'timezone': timezone,
        'language': 'es',
      }));

  Future<AuthSession> login(String identifier, String password) async => AuthSession.fromJson(
        await client.post('/api/auth/login', {'identifier': identifier, 'password': password}),
      );

  Future<AuthSession> loginWithGoogle(String idToken, String timezone) async => AuthSession.fromJson(
        await client.post('/api/auth/google', {'id_token': idToken, 'timezone': timezone}),
      );

  Future<AuthSession> loginWithApple(String idToken, String? fullName, String timezone) async =>
      AuthSession.fromJson(await client.post('/api/auth/apple', {
        'id_token': idToken,
        'full_name': fullName,
        'timezone': timezone,
      }));

  Future<void> logout(String refreshToken) =>
      client.post('/api/auth/logout', {'refresh_token': refreshToken});

  Future<String> forgotPassword(String email) async =>
      (await client.post('/api/auth/password/forgot', {'email': email}))['message'] as String;

  Future<String> resetPassword(String token, String password) async =>
      (await client.post('/api/auth/password/reset', {'token': token, 'password': password}))['message']
          as String;

  Future<bool> usernameAvailable(String username) async =>
      (await client.get('/api/auth/username-available', query: {'username': username}))['available']
          as bool;

  // ------------------------------------------------------------------ perfil

  Future<UserProfile> me() async => UserProfile.fromJson(await client.get('/api/me'));

  Future<UserProfile> updateMe(Map<String, Object?> changes) async =>
      UserProfile.fromJson(await client.put('/api/me', changes));

  Future<void> changePassword(String current, String next) =>
      client.put('/api/me/password', {'current_password': current, 'new_password': next});

  Future<void> deleteAccount() => client.delete('/api/me');

  Future<UserProfile> uploadAvatar(List<int> bytes) async =>
      UserProfile.fromJson(await client.postBytes('/api/me/avatar', bytes));

  Future<UserProfile> deleteAvatar() async => UserProfile.fromJson(await client.delete('/api/me/avatar'));

  Future<UserProfile> changeEmail(String email, String password) async =>
      UserProfile.fromJson(await client.put('/api/me/email', {'email': email, 'password': password}));

  Future<String> resendVerification() async =>
      (await client.post('/api/me/email/resend'))['message'] as String;

  Future<UserProfile> verifyEmail(String token) async =>
      UserProfile.fromJson(await client.post('/api/auth/email/verify', {'token': token}));

  Future<void> logoutEverywhere() => client.post('/api/me/logout-all');

  Future<UserSettings> settings() async => UserSettings.fromJson(await client.get('/api/me/settings'));

  Future<UserSettings> saveSettings(UserSettings s) async =>
      UserSettings.fromJson(await client.put('/api/me/settings', s.toJson()));

  Future<List<PublicUser>> searchUsers(String q) async =>
      parseList((await client.get('/api/users/search', query: {'q': q}))['users'], PublicUser.fromJson);

  // --------------------------------------------------------------- contactos

  Future<List<Contact>> contacts() async =>
      parseList((await client.get('/api/contacts'))['contacts'], Contact.fromJson);

  Future<Contact> requestConnection({String? userId, String? username, String? email, String? phone}) async =>
      Contact.fromJson(await client.post('/api/contacts/request', {
        'user_id': ?userId,
        'username': ?username,
        'email': ?email,
        'phone': ?phone,
      }));

  Future<Contact> acceptConnection(String id) async =>
      Contact.fromJson(await client.post('/api/contacts/$id/accept'));

  Future<void> rejectConnection(String id) => client.post('/api/contacts/$id/reject');
  Future<void> blockConnection(String id) => client.post('/api/contacts/$id/block');
  Future<void> unblockConnection(String id) => client.post('/api/contacts/$id/unblock');
  Future<void> removeConnection(String id) => client.delete('/api/contacts/$id');

  Future<Contact> updatePermissions(String id, ConnectionPermissions p) async =>
      Contact.fromJson(await client.put('/api/contacts/$id/permissions', p.toJson()));

  Future<InvitationCode> invitationCode() async =>
      InvitationCode.fromJson(await client.post('/api/contacts/invitation'));

  Future<Contact> connectWithCode(String code) async =>
      Contact.fromJson(await client.post('/api/contacts/connect', {'code': code}));

  // ------------------------------------------------------------------ grupos

  Future<List<Group>> groups() async =>
      parseList((await client.get('/api/groups'))['groups'], Group.fromJson);

  Future<Group> createGroup(String name, {String? description, List<String> memberIds = const []}) async =>
      Group.fromJson(await client.post('/api/groups', {
        'name': name,
        'description': description,
        'member_ids': memberIds,
      }));

  Future<Group> updateGroup(String id, String name, String? description, {GroupAlarmPolicy? alarmPolicy}) async =>
      Group.fromJson(await client.put('/api/groups/$id', {
        'name': name,
        'description': description,
        'alarm_policy': ?alarmPolicy?.wire,
      }));

  Future<void> deleteGroup(String id) => client.delete('/api/groups/$id');

  Future<Group> addMembers(String id, List<String> userIds) async =>
      Group.fromJson(await client.post('/api/groups/$id/members', {'user_ids': userIds}));

  Future<void> removeMember(String id, String userId) => client.delete('/api/groups/$id/members/$userId');

  Future<Group> setMemberRole(String id, String userId, GroupRole role) async =>
      Group.fromJson(await client.put('/api/groups/$id/members/$userId/role', {'role': role.wire}));

  Future<Group> acceptGroup(String id) async => Group.fromJson(await client.post('/api/groups/$id/accept'));

  Future<void> leaveGroup(String id) => client.post('/api/groups/$id/leave');

  Future<Group> updateGroupMembership(String id, {required bool allowAlarms, required bool autoAccept}) async =>
      Group.fromJson(await client.put('/api/groups/$id/me', {
        'allow_group_alarms': allowAlarms,
        'auto_accept': autoAccept,
      }));

  // ----------------------------------------------------------------- alarmas

  Future<Alarm> createAlarm(AlarmInput input) async =>
      Alarm.fromJson(await client.post('/api/alarms', input.toJson()));

  Future<Alarm> updateAlarm(String id, AlarmInput input) async =>
      Alarm.fromJson(await client.put('/api/alarms/$id', input.toJson()));

  Future<Alarm> getAlarm(String id) async => Alarm.fromJson(await client.get('/api/alarms/$id'));

  Future<void> deleteAlarm(String id) => client.delete('/api/alarms/$id');

  Future<Alarm> cancelNextOccurrence(String id) async =>
      Alarm.fromJson(await client.post('/api/alarms/$id/cancel'));

  Future<Alarm> respond(String id, RespondInput input) async {
    final action = switch (input.response) {
      ResponseStatus.confirmed => 'confirm',
      ResponseStatus.snoozed => 'snooze',
      _ => 'dismiss',
    };
    return Alarm.fromJson(await client.post('/api/alarms/$id/$action', input.toJson()));
  }

  Future<Alarm> acceptAlarm(String id) async => Alarm.fromJson(await client.post('/api/alarms/$id/accept'));

  Future<void> rejectAlarm(String id) => client.post('/api/alarms/$id/reject');

  Future<List<AlarmResponse>> alarmResponses(String id) async =>
      parseList((await client.get('/api/alarms/$id/responses'))['responses'], AlarmResponse.fromJson);

  Future<void> setAlarmDevice(String alarmId, String deviceId, bool enabled) =>
      client.put('/api/alarms/$alarmId/devices/$deviceId', {'enabled': enabled});

  Future<Map<String, Map<String, bool>>> devicePreferences() async {
    final json = (await client.get('/api/alarms/device-preferences'))['preferences'] as Map;
    return {
      for (final e in json.entries)
        e.key as String: Map<String, bool>.from(e.value as Map),
    };
  }

  // ------------------------------------------------------------ dispositivos

  Future<List<Device>> devices() async =>
      parseList((await client.get('/api/devices'))['devices'], Device.fromJson);

  Future<Device> registerDevice(DeviceInput input) async =>
      Device.fromJson(await client.post('/api/devices', input.toJson()));

  Future<Device> updateDevice(String id, {String? name, bool? receivesAlarms}) async =>
      Device.fromJson(await client.put('/api/devices/$id', {
        'device_name': ?name,
        'receives_alarms': ?receivesAlarms,
      }));

  Future<void> removeDevice(String id) => client.delete('/api/devices/$id');

  // ---------------------------------------- sincronización y notificaciones

  Future<SyncPayload> sync(int cursor) async =>
      SyncPayload.fromJson(await client.get('/api/sync', query: {'cursor': cursor}));

  Future<void> markNotificationRead(String id) => client.post('/api/notifications/$id/read');

  Future<List<AppNotification>> notifications({DateTime? before, int limit = 50}) async => parseList(
        (await client.get('/api/notifications', query: {
          'before': before?.toUtc().toIso8601String(),
          'limit': limit,
        }))['notifications'],
        AppNotification.fromJson,
      );

  // ----------------------------------------------------------------- rutinas

  Future<List<AlarmSequence>> sequences() async =>
      parseList((await client.get('/api/sequences'))['sequences'], AlarmSequence.fromJson);

  Future<AlarmSequence> createSequence(SequenceInput input) async =>
      AlarmSequence.fromJson(await client.post('/api/sequences', input.toJson()));

  Future<void> deleteSequence(String id) => client.delete('/api/sequences/$id');

  Future<void> markAllNotificationsRead() => client.post('/api/notifications/read-all');

  // ---------------------------------------------- historial y estadísticas

  Future<List<HistoryEntry>> history({String filter = 'all', DateTime? before}) async => parseList(
        (await client.get('/api/history', query: {
          'filter': filter,
          'before': before?.toUtc().toIso8601String(),
        }))['entries'],
        HistoryEntry.fromJson,
      );

  Future<(AlarmStats, List<GroupStats>)> stats({bool allTime = false}) async {
    final json = await client.get('/api/stats', query: {'period': allTime ? 'all' : 'month'});
    return (
      AlarmStats.fromJson(json['user'] as JsonMap),
      parseList(json['groups'], GroupStats.fromJson),
    );
  }

  // -------------------------------------------------------------------- chat

  Future<void> createChatSession(String id) => client.post('/api/chat/sessions', {'id': id});

  Future<List<ChatSession>> chatSessions() async =>
      parseList((await client.get('/api/chat/sessions'))['sessions'], ChatSession.fromJson);

  Future<void> appendChatMessages(String sessionId, List<ChatMessage> messages) =>
      client.post('/api/chat/sessions/$sessionId/messages', {
        'messages': [for (final m in messages) m.toJson()],
      });

  Future<List<ChatMessage>> chatMessages(String sessionId) async => parseList(
        (await client.get('/api/chat/sessions/$sessionId/messages'))['messages'],
        ChatMessage.fromJson,
      );
}
