import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ally_core/ally_core.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../data/local/local_store.dart';
import '../../services/device_service.dart';
import '../session_controller.dart';
import 'command_executor.dart';
import 'voice_policy.dart';

/// Mensaje del chat tal como se muestra.
class ChatItem {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime at;

  /// Interpretación asociada (resumen, aclaraciones y botones).
  final InterpretationResult? interpretation;

  /// Enlace sugerido tras ejecutar (p. ej. "Ver alarma").
  final String? route;
  final String? routeLabel;

  /// Los botones solo se muestran en el último mensaje pendiente.
  final bool active;

  const ChatItem({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.interpretation,
    this.route,
    this.routeLabel,
    this.active = false,
  });

  ChatItem inactive() => ChatItem(
        id: id,
        role: role,
        text: text,
        at: at,
        interpretation: interpretation,
        route: route,
        routeLabel: routeLabel,
      );

  ChatMessage toMessage(String sessionId) => ChatMessage(
        id: id,
        sessionId: sessionId,
        role: role,
        content: text,
        createdAt: at,
        payload: {
          if (interpretation != null) 'interpretation': interpretation!.toJson(),
          'route': ?route,
          'route_label': ?routeLabel,
        },
      );

  static ChatItem fromMessage(ChatMessage m) {
    final payload = m.payload ?? const {};
    return ChatItem(
      id: m.id,
      role: m.role,
      text: m.content,
      at: m.createdAt,
      interpretation: payload['interpretation'] == null
          ? null
          : InterpretationResult.fromJson(payload['interpretation'] as JsonMap),
      route: payload['route'] as String?,
      routeLabel: payload['route_label'] as String?,
    );
  }
}

class ChatState {
  final List<ChatItem> items;
  final bool busy;

  /// Interpretación que espera respuesta (aclaración o confirmación).
  final InterpretationResult? pending;

  const ChatState({this.items = const [], this.busy = false, this.pending});

  ChatState copyWith({List<ChatItem>? items, bool? busy, InterpretationResult? pending, bool clearPending = false}) =>
      ChatState(
        items: items ?? this.items,
        busy: busy ?? this.busy,
        pending: clearPending ? null : (pending ?? this.pending),
      );
}

/// Historial del asistente en este dispositivo. Lo comparten el chat y las
/// órdenes por voz («Hey Ally»), que se ejecutan sin abrir la app.
class ChatHistory {
  static const _uuid = Uuid();
  static const _sessionKey = 'chat_session_id';
  final LocalStore store;
  String? _sessionId;

  ChatHistory(this.store);

  Future<String> sessionId() async {
    if (_sessionId != null) return _sessionId!;
    _sessionId = await store.db.getValue(_sessionKey);
    if (_sessionId == null) {
      _sessionId = _uuid.v4();
      await store.db.setValue(_sessionKey, _sessionId!);
    }
    return _sessionId!;
  }

  /// Pasa a usar la conversación [id] (p. ej. recuperada del servidor).
  Future<void> adopt(String id) async {
    _sessionId = id;
    await store.db.setValue(_sessionKey, id);
  }

  /// Guarda los mensajes localmente y los encola para el servidor.
  Future<void> save(List<ChatItem> items) async {
    final session = await sessionId();
    final messages = [for (final i in items) i.toMessage(session)];
    for (final m in messages) {
      await store.saveChatMessage(m);
    }
    await store.enqueue(OutboxKind.chatMessages, session, {
      'session_id': session,
      'messages': [for (final m in messages) m.toJson()],
    });
  }
}

/// Orquesta la conversación con el asistente. Todo se interpreta en el
/// dispositivo con el motor de reglas (funciona sin conexión); el historial
/// se guarda localmente y se sincroniza con el servidor.
class ChatController extends Notifier<ChatState> {
  static const _uuid = Uuid();
  late ChatHistory _history;

  /// Texto a leer en voz alta tras la última orden por voz.
  String? _speech;

  /// Acciones de interfaz que el controlador no puede hacer por sí mismo.
  void Function(String route)? onNavigate;

  @override
  ChatState build() {
    // Se reconstruye al cambiar de usuario: el historial nunca se mezcla.
    final userId = ref.watch(sessionProvider.select((s) => s is SignedIn ? s.user.id : null));
    _history = ChatHistory(_store);
    if (userId == null) return const ChatState();
    // Al volver a la app se recargan las órdenes dadas por voz mientras tanto.
    final lifecycle = AppLifecycleListener(onResume: () {
      if (!state.busy && state.pending == null) unawaited(_load());
    });
    ref.onDispose(lifecycle.dispose);
    unawaited(_load());
    return const ChatState(busy: true);
  }

  LocalStore get _store => ref.read(appServicesProvider).store;

  Future<void> _load() async {
    var session = await _history.sessionId();
    var messages = await _store.chatMessages(session);
    if (messages.isEmpty) {
      final restored = await _restoreFromServer();
      if (restored != null) (session, messages) = restored;
    }
    var items = [for (final m in messages) ChatItem.fromMessage(m)];
    if (items.isEmpty) {
      final me = await _store.me();
      final name = me?.displayName.split(' ').first ?? '';
      items = [
        ChatItem(
          id: _uuid.v4(),
          role: ChatRole.system,
          text: 'Hola${name.isEmpty ? '' : ' $name'} 👋\n¿Qué alarma quieres crear?',
          at: DateTime.now().toUtc(),
        ),
      ];
    }
    state = ChatState(items: items);
  }

  /// En un dispositivo nuevo (sin historial local) recupera la última
  /// conversación guardada en el servidor.
  Future<(String, List<ChatMessage>)?> _restoreFromServer() async {
    final api = ref.read(appServicesProvider).api;
    try {
      final sessions = await api.chatSessions();
      if (sessions.isEmpty) return null;
      final latest = sessions.first;
      final messages = await api.chatMessages(latest.id);
      if (messages.isEmpty) return null;
      for (final m in messages) {
        await _store.saveChatMessage(m);
      }
      await _history.adopt(latest.id);
      return (latest.id, messages);
    } catch (_) {
      return null; // Sin conexión: se empieza una conversación nueva.
    }
  }

  /// Igual que [send], pero dictado por voz: las alarmas se crean sin pedir
  /// confirmación (ver [VoicePolicy]). Devuelve el texto a leer en voz alta.
  Future<String?> sendVoice(String text) async {
    _speech = null;
    final before = state.items.length;
    await send(text, voice: true);
    if (state.items.length == before) return null;
    if (_speech != null) return _speech;
    final last = state.items.last;
    if (last.role != ChatRole.system) return null;
    return last.interpretation != null && last.active
        ? VoicePolicy.speech(last.interpretation!)
        : VoicePolicy.clean(last.text);
  }

  Future<void> send(String rawText, {bool voice = false}) async {
    final text = rawText.trim();
    if (text.isEmpty || state.busy) return;
    final userItem = _item(ChatRole.user, text);
    _append([userItem], busy: true);

    try {
      final pending = state.pending;
      if (pending?.status == InterpretationStatus.needsConfirmation) {
        switch (const ConfirmationReplyParser().parse(text)) {
          case ConfirmationReply.confirm:
            return await _execute(pending!.draft);
          case ConfirmationReply.reject:
            return _reply('Cancelado. ¿Quieres hacer algo más?', clearPending: true);
          case ConfirmationReply.unknown:
            break;
        }
      }
      final ctx = await _context();
      final interpreter = ref.read(interpreterProvider);
      final result = pending?.status == InterpretationStatus.needsClarification
          ? await interpreter.answer(pending!, text, ctx)
          : await interpreter.interpret(text, ctx);
      await _handle(result, voice: voice);
    } catch (e) {
      _reply(userMessage(e), clearPending: true);
    }
  }

  Future<void> chooseOption(ClarificationOption option) async {
    final pending = state.pending;
    if (pending == null || state.busy) return;
    _append([_item(ChatRole.user, option.label)], busy: true);
    try {
      switch (option.action) {
        case OptionAction.cancel:
          return _reply('Cancelado. ¿Quieres hacer algo más?', clearPending: true);
        case OptionAction.searchUsers:
          final subject = pending.pendingClarification?.subject ?? '';
          onNavigate?.call('/contacts/add?q=${Uri.encodeQueryComponent(subject)}');
        case OptionAction.inviteUser:
          onNavigate?.call('/contacts/add?tab=invite');
        case OptionAction.none:
          break;
      }
      final result = await ref.read(interpreterProvider).applyOption(pending.draft, option, await _context());
      await _handle(result);
    } catch (e) {
      _reply(userMessage(e), clearPending: true);
    }
  }

  Future<void> confirm() async {
    final pending = state.pending;
    if (pending == null || state.busy) return;
    _append([_item(ChatRole.user, pending.confirmation?.confirmLabel ?? 'Confirmar')], busy: true);
    try {
      await _execute(pending.draft);
    } catch (e) {
      _reply(userMessage(e), clearPending: true);
    }
  }

  void cancel() {
    if (state.pending == null || state.busy) return;
    _append([_item(ChatRole.user, 'Cancelar')]);
    _reply('Cancelado. ¿Quieres hacer algo más?', clearPending: true);
  }

  /// Borrador pendiente (para abrir el formulario en "Editar").
  CommandDraft? takePendingDraft() {
    final draft = state.pending?.draft;
    if (draft != null) {
      _deactivate();
      state = state.copyWith(clearPending: true);
    }
    return draft;
  }

  Future<void> clearHistory() async {
    await _store.clearChat(await _history.sessionId());
    await _history.adopt(_uuid.v4());
    state = const ChatState(busy: true);
    await _load();
  }

  // ------------------------------------------------------------ internos

  Future<void> _handle(InterpretationResult result, {bool voice = false}) async {
    if (voice && VoicePolicy.autoExecutes(result)) {
      _append([_item(ChatRole.system, result.reply, interpretation: result)]);
      return _execute(result.draft, voiceResult: result);
    }
    switch (result.status) {
      case InterpretationStatus.readyToExecute:
        return _execute(result.draft);
      case InterpretationStatus.needsConfirmation:
      case InterpretationStatus.needsClarification:
        _deactivate();
        _append([_item(ChatRole.system, result.reply, interpretation: result, active: true)]);
        state = state.copyWith(busy: false, pending: result);
      case InterpretationStatus.invalid:
      case InterpretationStatus.notUnderstood:
        _reply(result.reply, clearPending: true);
    }
  }

  Future<void> _execute(CommandDraft draft, {InterpretationResult? voiceResult}) async {
    final ringing = {
      for (final r in ref.read(ringingProvider).value ?? const <RingingAlarm>[]) r.alarmId: r.occurrenceAt,
    };
    final ExecutionResult result;
    try {
      result = await ref.read(commandExecutorProvider).execute(draft, ringingOccurrences: ringing);
    } catch (e) {
      return _reply(
        e is AppException ? e.message : 'No pude completar la acción. Inténtalo de nuevo.',
        clearPending: true,
      );
    }
    _deactivate();
    _append([_item(ChatRole.system, result.reply, route: result.route, routeLabel: result.routeLabel)]);
    state = state.copyWith(busy: false, clearPending: true);
    if (voiceResult != null) _speech = VoicePolicy.created(voiceResult, result.reply);
  }

  void _reply(String text, {bool clearPending = false}) {
    if (clearPending) _deactivate();
    _append([_item(ChatRole.system, text)]);
    state = state.copyWith(busy: false, clearPending: clearPending);
  }

  void _deactivate() {
    state = state.copyWith(items: [for (final i in state.items) i.active ? i.inactive() : i]);
  }

  void _append(List<ChatItem> items, {bool? busy}) {
    state = state.copyWith(items: [...state.items, ...items], busy: busy);
    unawaited(_history.save(items));
  }

  ChatItem _item(
    ChatRole role,
    String text, {
    InterpretationResult? interpretation,
    String? route,
    String? routeLabel,
    bool active = false,
  }) =>
      ChatItem(
        id: _uuid.v4(),
        role: role,
        text: text,
        at: DateTime.now().toUtc(),
        interpretation: interpretation,
        route: route,
        routeLabel: routeLabel,
        active: active,
      );

  Future<InterpretationContext> _context() async {
    final ringing = {for (final r in ref.read(ringingProvider).value ?? const <RingingAlarm>[]) r.alarmId};
    return ref.read(contextBuilderProvider).build(
          timezone: await DeviceService.currentTimezone(),
          ringingAlarmIds: ringing,
        );
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
