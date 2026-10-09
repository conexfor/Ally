import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ally_core/ally_core.dart';

import '../core/errors/app_exception.dart';
import '../data/local/local_store.dart';
import '../data/remote/ally_api.dart';
import 'alarm_scheduler.dart';

class SyncResult {
  final bool success;
  final bool offline;
  final List<AppNotification> newNotifications;

  const SyncResult({required this.success, this.offline = false, this.newNotifications = const []});
}

/// Sincroniza el dispositivo con el servidor:
///
/// 1. Envía la cola de operaciones locales (creadas sin conexión) en orden.
/// 2. Descarga los cambios desde el último cursor.
/// 3. Reprograma las alarmas nativas.
///
/// Resolución de conflictos:
/// - Las alarmas con operaciones pendientes no se sobrescriben con datos del
///   servidor hasta que esas operaciones se envían.
/// - Si una edición choca con otra más reciente (409): en alarmas personales
///   gana la última edición (se reaplica); en alarmas compartidas gana el
///   servidor y se avisa al usuario.
/// - Respuestas (confirmar/posponer) son idempotentes en el servidor.
class SyncEngine {
  final AllyApi api;
  final LocalStore store;
  final AlarmScheduler scheduler;

  Future<SyncResult>? _running;

  SyncEngine(this.api, this.store, this.scheduler);

  /// Ejecuta una sincronización (si ya hay una en curso, devuelve esa).
  Future<SyncResult> sync() => _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncResult> _sync() async {
    try {
      final pushed = await _pushOutbox();
      if (!pushed) {
        await scheduler.reschedule();
        return const SyncResult(success: false, offline: true);
      }
      final newNotifications = await _pull();
      try {
        await store.saveDevicePreferences(await api.devicePreferences());
      } on AppException catch (e) {
        debugPrint('Preferencias de dispositivo: $e');
      }
      await store.saveLastSync(DateTime.now());
      await scheduler.reschedule();
      return SyncResult(success: true, newNotifications: newNotifications);
    } on AppException catch (e) {
      await scheduler.reschedule();
      return SyncResult(success: false, offline: e.isNetwork);
    }
  }

  // -------------------------------------------------------------- enviar cola

  /// Devuelve `false` si se detuvo por falta de conexión.
  Future<bool> _pushOutbox() async {
    for (final item in await store.outbox()) {
      try {
        await _send(item);
        await store.removeOutbox(item.id);
      } on AppException catch (e) {
        if (e.isNetwork) return false;
        if (e.isPermanent) {
          await store.removeOutbox(item.id);
          await _onRejected(item, e);
        } else {
          await store.markOutboxFailed(item.id, e.message);
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _send(OutboxItem item) async {
    switch (item.kind) {
      case OutboxKind.createAlarm:
        final alarm = await api.createAlarm(AlarmInput.fromJson(item.payload));
        await store.upsertAlarm(alarm);
      case OutboxKind.updateAlarm:
        await _sendUpdate(item);
      case OutboxKind.deleteAlarm:
        try {
          await api.deleteAlarm(item.entityId);
        } on AppException catch (e) {
          if (e.status != 404) rethrow;
        }
        await store.removeAlarm(item.entityId);
      case OutboxKind.cancelAlarm:
        try {
          await store.upsertAlarm(await api.cancelNextOccurrence(item.entityId));
        } on AppException catch (e) {
          if (e.status != 409) rethrow;
        }
      case OutboxKind.respond:
        final alarm = await api.respond(item.entityId, RespondInput.fromJson(item.payload));
        await store.upsertAlarm(alarm);
      case OutboxKind.chatMessages:
        final sessionId = item.payload['session_id'] as String;
        await api.createChatSession(sessionId);
        await api.appendChatMessages(
          sessionId,
          parseList(item.payload['messages'], ChatMessage.fromJson),
        );
    }
  }

  Future<void> _sendUpdate(OutboxItem item) async {
    final input = AlarmInput.fromJson(item.payload);
    try {
      await store.upsertAlarm(await api.updateAlarm(item.entityId, input));
    } on AppException catch (e) {
      if (e.code != 'version_conflict') rethrow;
      final server = await api.getAlarm(item.entityId);
      final personal = server.recipients.every(
        (r) => r.recipientType != RecipientType.group && r.userId == server.creator.id,
      );
      if (personal) {
        // Última edición gana: se reaplica sobre la versión actual.
        final retry = AlarmInput.fromJson({...input.toJson(), 'base_version': server.version});
        await store.upsertAlarm(await api.updateAlarm(item.entityId, retry));
      } else {
        await store.upsertAlarm(server);
        await store.addSyncIssue(
          'Tus cambios en «${server.title}» no se aplicaron porque la alarma se '
          'modificó desde otro dispositivo. Revisa la versión actual.',
        );
      }
    }
  }

  Future<void> _onRejected(OutboxItem item, AppException e) async {
    switch (item.kind) {
      case OutboxKind.createAlarm:
        final title = item.payload['title'] as String? ?? 'Alarma';
        await store.removeAlarm(item.entityId);
        await store.addSyncIssue('No se pudo crear «$title»: ${e.message}');
      case OutboxKind.updateAlarm:
        await store.addSyncIssue('No se pudieron guardar cambios de una alarma: ${e.message}');
      case OutboxKind.respond:
      case OutboxKind.cancelAlarm:
      case OutboxKind.deleteAlarm:
      case OutboxKind.chatMessages:
        debugPrint('Operación descartada (${item.kind}): ${e.message}');
    }
  }

  // ----------------------------------------------------------- recibir cambios

  Future<List<AppNotification>> _pull() async {
    final me = await store.me();
    if (me == null) return const [];
    var cursor = await store.syncCursor();
    final newNotifications = <AppNotification>[];
    while (true) {
      final payload = await api.sync(cursor);
      await _apply(payload, me.id, firstPage: cursor == 0);
      newNotifications.addAll(payload.notifications.where((n) => !n.isRead));
      cursor = payload.cursor;
      await store.saveSyncCursor(cursor);
      if (!payload.hasMore) break;
    }
    return newNotifications;
  }

  Future<void> _apply(SyncPayload payload, String me, {required bool firstPage}) async {
    if (payload.fullResync && firstPage) {
      for (final alarm in await store.alarms()) {
        if (!await store.hasOutboxFor(alarm.id)) await store.removeAlarm(alarm.id);
      }
    }
    for (final alarm in payload.alarms) {
      if (await store.hasOutboxFor(alarm.id)) continue;
      final myRow = alarm.recipientFor(me);
      final noLongerMine = alarm.creator.id != me &&
          (myRow == null || myRow.permissionStatus == PermissionStatus.rejected);
      if (alarm.isDeleted || noLongerMine) {
        await store.removeAlarm(alarm.id);
      } else {
        await store.upsertAlarm(alarm);
      }
    }
    for (final response in payload.responses) {
      await store.upsertResponse(response);
    }
    await store.saveContacts(payload.contacts);
    await store.saveGroups(payload.groups);
    for (final n in payload.notifications) {
      await store.upsertNotification(n);
    }
  }
}
