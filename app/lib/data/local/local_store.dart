import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ally_core/ally_core.dart';

import 'app_database.dart';

/// Operación pendiente de enviar al servidor.
class OutboxItem {
  final int id;
  final String kind;
  final String entityId;
  final JsonMap payload;
  final int attempts;

  const OutboxItem(this.id, this.kind, this.entityId, this.payload, this.attempts);
}

/// Tipos de operación de la cola offline.
abstract final class OutboxKind {
  static const createAlarm = 'create_alarm';
  static const updateAlarm = 'update_alarm';
  static const deleteAlarm = 'delete_alarm';
  static const cancelAlarm = 'cancel_alarm';
  static const respond = 'respond';
  static const chatMessages = 'chat_messages';
}

/// Acceso tipado a la base de datos local.
class LocalStore {
  final AppDatabase db;
  LocalStore(this.db);

  static const _meKey = 'me';
  static const _settingsKey = 'settings';
  static const _contactsKey = 'contacts';
  static const _groupsKey = 'groups';
  static const _cursorKey = 'sync_cursor';
  static const _deviceKey = 'device';
  static const _devicePrefsKey = 'device_preferences';
  static const _syncIssuesKey = 'sync_issues';
  static const _lastSyncKey = 'last_sync';

  // ------------------------------------------------------------------ alarmas

  Future<void> upsertAlarm(Alarm alarm, {bool pending = false}) =>
      db.into(db.localAlarms).insertOnConflictUpdate(LocalAlarmsCompanion.insert(
            id: alarm.id,
            json: jsonEncode(alarm.toJson()),
            creatorId: alarm.creator.id,
            nextOccurrenceMs: Value(alarm.nextOccurrenceAt?.millisecondsSinceEpoch),
            deleted: Value(alarm.isDeleted),
            pendingSync: Value(pending),
            updatedAtMs: alarm.updatedAt.millisecondsSinceEpoch,
          ));

  Future<void> removeAlarm(String id) =>
      (db.delete(db.localAlarms)..where((t) => t.id.equals(id))).go();

  Future<Alarm?> alarm(String id) async {
    final row = await (db.select(db.localAlarms)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _alarm(row);
  }

  Future<bool> hasPendingChanges(String alarmId) async =>
      (await (db.select(db.localAlarms)..where((t) => t.id.equals(alarmId))).getSingleOrNull())
          ?.pendingSync ??
      false;

  Future<List<Alarm>> alarms() async => [
        for (final row in await (db.select(db.localAlarms)..where((t) => t.deleted.equals(false))).get())
          _alarm(row),
      ];

  Stream<List<Alarm>> watchAlarms() => (db.select(db.localAlarms)
        ..where((t) => t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.nextOccurrenceMs, nulls: NullsOrder.last)]))
      .watch()
      .map((rows) => [for (final r in rows) _alarm(r)]);

  Stream<Alarm?> watchAlarm(String id) => (db.select(db.localAlarms)..where((t) => t.id.equals(id)))
      .watchSingleOrNull()
      .map((row) => row == null ? null : _alarm(row));

  Alarm _alarm(LocalAlarm row) => Alarm.fromJson(jsonDecode(row.json) as JsonMap);

  // --------------------------------------------------------------- respuestas

  Future<void> upsertResponse(AlarmResponse r) async {
    await (db.delete(db.localResponses)
          ..where((t) =>
              t.alarmId.equals(r.alarmId) &
              t.userId.equals(r.userId) &
              t.occurrenceMs.equals(r.occurrenceAt.millisecondsSinceEpoch) &
              t.id.equals(r.id).not()))
        .go();
    await db.into(db.localResponses).insertOnConflictUpdate(LocalResponsesCompanion.insert(
          id: r.id,
          alarmId: r.alarmId,
          userId: r.userId,
          occurrenceMs: r.occurrenceAt.millisecondsSinceEpoch,
          json: jsonEncode(r.toJson()),
        ));
  }

  Future<List<AlarmResponse>> responsesFor(String userId) async => [
        for (final row in await (db.select(db.localResponses)..where((t) => t.userId.equals(userId))).get())
          AlarmResponse.fromJson(jsonDecode(row.json) as JsonMap),
      ];

  Stream<List<AlarmResponse>> watchResponses(String alarmId) =>
      (db.select(db.localResponses)..where((t) => t.alarmId.equals(alarmId)))
          .watch()
          .map((rows) => [for (final r in rows) AlarmResponse.fromJson(jsonDecode(r.json) as JsonMap)]);

  // -------------------------------------------------- valores JSON (clave/valor)

  Future<T?> _readJson<T>(String key, T Function(Object? json) parse) async {
    final raw = await db.getValue(key);
    return raw == null ? null : parse(jsonDecode(raw));
  }

  Stream<T?> _watchJson<T>(String key, T Function(Object? json) parse) =>
      db.watchValue(key).map((raw) => raw == null ? null : parse(jsonDecode(raw)));

  Future<void> _writeJson(String key, Object? json) => db.setValue(key, jsonEncode(json));

  Future<UserProfile?> me() => _readJson(_meKey, (j) => UserProfile.fromJson(j as JsonMap));
  Stream<UserProfile?> watchMe() => _watchJson(_meKey, (j) => UserProfile.fromJson(j as JsonMap));
  Future<void> saveMe(UserProfile user) => _writeJson(_meKey, user.toJson());

  Future<UserSettings> settings() async =>
      await _readJson(_settingsKey, (j) => UserSettings.fromJson(j as JsonMap)) ?? const UserSettings();
  Stream<UserSettings> watchSettings() =>
      _watchJson(_settingsKey, (j) => UserSettings.fromJson(j as JsonMap)).map((s) => s ?? const UserSettings());
  Future<void> saveSettings(UserSettings s) => _writeJson(_settingsKey, s.toJson());

  Future<List<Contact>> contacts() async =>
      await _readJson(_contactsKey, (j) => parseList(j, Contact.fromJson)) ?? const [];
  Stream<List<Contact>> watchContacts() =>
      _watchJson(_contactsKey, (j) => parseList(j, Contact.fromJson)).map((c) => c ?? const []);
  Future<void> saveContacts(List<Contact> contacts) =>
      _writeJson(_contactsKey, [for (final c in contacts) c.toJson()]);

  Future<List<Group>> groups() async =>
      await _readJson(_groupsKey, (j) => parseList(j, Group.fromJson)) ?? const [];
  Stream<List<Group>> watchGroups() =>
      _watchJson(_groupsKey, (j) => parseList(j, Group.fromJson)).map((g) => g ?? const []);
  Future<void> saveGroups(List<Group> groups) => _writeJson(_groupsKey, [for (final g in groups) g.toJson()]);

  Future<Device?> device() => _readJson(_deviceKey, (j) => Device.fromJson(j as JsonMap));
  Future<void> saveDevice(Device device) => _writeJson(_deviceKey, device.toJson());

  /// alarm_id → device_id → activo
  Future<Map<String, Map<String, bool>>> devicePreferences() async =>
      await _readJson(_devicePrefsKey, (j) => {
                for (final e in (j as Map).entries)
                  e.key as String: Map<String, bool>.from(e.value as Map),
              }) ??
      const {};
  Future<void> saveDevicePreferences(Map<String, Map<String, bool>> prefs) =>
      _writeJson(_devicePrefsKey, prefs);

  Future<int> syncCursor() async => int.tryParse(await db.getValue(_cursorKey) ?? '') ?? 0;
  Future<void> saveSyncCursor(int cursor) => db.setValue(_cursorKey, '$cursor');

  Future<DateTime?> lastSync() async {
    final raw = await db.getValue(_lastSyncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Stream<DateTime?> watchLastSync() =>
      db.watchValue(_lastSyncKey).map((raw) => raw == null ? null : DateTime.tryParse(raw));
  Future<void> saveLastSync(DateTime at) => db.setValue(_lastSyncKey, at.toUtc().toIso8601String());

  /// Avisos de sincronización para mostrar al usuario (p. ej. conflictos).
  Future<List<String>> syncIssues() async =>
      await _readJson(_syncIssuesKey, (j) => List<String>.from(j as List)) ?? const [];
  Stream<List<String>> watchSyncIssues() =>
      _watchJson(_syncIssuesKey, (j) => List<String>.from(j as List)).map((i) => i ?? const []);
  Future<void> addSyncIssue(String message) async {
    final issues = [...await syncIssues(), message];
    await _writeJson(_syncIssuesKey, issues.length > 20 ? issues.sublist(issues.length - 20) : issues);
  }

  Future<void> clearSyncIssues() => db.removeValue(_syncIssuesKey);

  // ---------------------------------------------------------- notificaciones

  Future<void> upsertNotification(AppNotification n) =>
      db.into(db.localNotifications).insertOnConflictUpdate(LocalNotificationsCompanion.insert(
            id: n.id,
            json: jsonEncode(n.toJson()),
            createdAtMs: n.createdAt.millisecondsSinceEpoch,
            read: Value(n.isRead),
          ));

  Stream<List<AppNotification>> watchNotifications({int limit = 50}) => (db.select(db.localNotifications)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
        ..limit(limit))
      .watch()
      .map((rows) => [
            for (final r in rows)
              _notificationWithRead(AppNotification.fromJson(jsonDecode(r.json) as JsonMap), r.read),
          ]);

  Stream<int> watchUnreadCount() => (db.select(db.localNotifications)..where((t) => t.read.equals(false)))
      .watch()
      .map((rows) => rows.length);

  Future<void> markNotificationsRead({String? id}) => (db.update(db.localNotifications)
        ..where((t) => id == null ? const Constant(true) : t.id.equals(id)))
      .write(const LocalNotificationsCompanion(read: Value(true)));

  AppNotification _notificationWithRead(AppNotification n, bool read) => AppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        alarmId: n.alarmId,
        createdAt: n.createdAt,
        readAt: read ? (n.readAt ?? n.createdAt) : null,
      );

  // ------------------------------------------------------------- cola offline

  Future<void> enqueue(String kind, String entityId, JsonMap payload) =>
      db.into(db.outboxEntries).insert(OutboxEntriesCompanion.insert(
            kind: kind,
            entityId: entityId,
            payload: jsonEncode(payload),
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ));

  Future<List<OutboxItem>> outbox() async => [
        for (final row in await (db.select(db.outboxEntries)..orderBy([(t) => OrderingTerm.asc(t.id)])).get())
          OutboxItem(row.id, row.kind, row.entityId, jsonDecode(row.payload) as JsonMap, row.attempts),
      ];

  Stream<int> watchOutboxCount() => db.select(db.outboxEntries).watch().map((rows) => rows.length);

  Future<void> removeOutbox(int id) => (db.delete(db.outboxEntries)..where((t) => t.id.equals(id))).go();

  Future<void> markOutboxFailed(int id, String error) => db.customStatement(
        'UPDATE outbox_entries SET attempts = attempts + 1, last_error = ? WHERE id = ?',
        [error, id],
      );

  /// ¿Hay operaciones pendientes sobre esta entidad? (no se pisan con datos
  /// del servidor hasta enviarlas).
  Future<bool> hasOutboxFor(String entityId) async =>
      (await (db.select(db.outboxEntries)..where((t) => t.entityId.equals(entityId))).get()).isNotEmpty;

  // -------------------------------------------------------------------- chat

  Future<void> saveChatMessage(ChatMessage m) =>
      db.into(db.localChatMessages).insertOnConflictUpdate(LocalChatMessagesCompanion.insert(
            id: m.id,
            sessionId: m.sessionId,
            role: m.role.wire,
            content: m.content,
            payload: Value(m.payload == null ? null : jsonEncode(m.payload)),
            createdAtMs: m.createdAt.millisecondsSinceEpoch,
          ));

  Future<List<ChatMessage>> chatMessages(String sessionId, {int limit = 200}) async {
    final rows = await (db.select(db.localChatMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
          ..limit(limit))
        .get();
    return [
      for (final r in rows.reversed)
        ChatMessage(
          id: r.id,
          sessionId: r.sessionId,
          role: ChatRole.fromWire(r.role),
          content: r.content,
          payload: r.payload == null ? null : jsonDecode(r.payload!) as JsonMap,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMs, isUtc: true),
        ),
    ];
  }

  Future<void> clearChat(String sessionId) =>
      (db.delete(db.localChatMessages)..where((t) => t.sessionId.equals(sessionId))).go();

  // ------------------------------------------------- alarmas nativas programadas

  Future<List<ScheduledNativeAlarm>> scheduledNative() => db.select(db.scheduledNativeAlarms).get();

  Future<ScheduledNativeAlarm?> scheduledNativeById(int nativeId) =>
      (db.select(db.scheduledNativeAlarms)..where((t) => t.nativeId.equals(nativeId))).getSingleOrNull();

  Future<void> saveScheduledNative(int nativeId, String alarmId, DateTime occurrence, DateTime ringAt) =>
      db.into(db.scheduledNativeAlarms).insertOnConflictUpdate(ScheduledNativeAlarmsCompanion.insert(
            nativeId: Value(nativeId),
            alarmId: alarmId,
            occurrenceMs: occurrence.millisecondsSinceEpoch,
            ringAtMs: ringAt.millisecondsSinceEpoch,
          ));

  Future<void> removeScheduledNative(int nativeId) =>
      (db.delete(db.scheduledNativeAlarms)..where((t) => t.nativeId.equals(nativeId))).go();

  Future<void> clearAll() => db.clearAll();
}
