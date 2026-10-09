import 'package:ally_core/ally_core.dart';

import '../../db/database.dart';
import '../../http/api_exception.dart';

/// Historial de conversaciones con el asistente.
class ChatService {
  final Db db;
  ChatService(this.db);

  static const maxContentLength = 4000;

  Future<List<ChatSession>> sessions(String me) async {
    final rows = await db.query(
      'SELECT id::text AS id, title, created_at, updated_at FROM chat_sessions '
      'WHERE user_id = @me::uuid ORDER BY updated_at DESC LIMIT 50',
      {'me': me},
    );
    return [for (final r in rows) _session(r)];
  }

  Future<ChatSession> createSession(String me, {String? id, String? title}) async {
    if (id != null && !Validators.isUuid(id)) {
      throw const ApiException.badRequest('El identificador no es válido.');
    }
    final row = await db.one(
      '''
      INSERT INTO chat_sessions (id, user_id, title) VALUES (COALESCE(@id::uuid, gen_random_uuid()), @me::uuid, @title)
      ON CONFLICT (id) DO NOTHING
      RETURNING id::text AS id, title, created_at, updated_at
      ''',
      {'id': id, 'me': me, 'title': _title(title)},
    );
    if (row != null) return _session(row);
    return _requireSession(me, id!);
  }

  Future<List<ChatMessage>> messages(String me, String sessionId, {int limit = 200}) async {
    await _requireSession(me, sessionId);
    final rows = await db.query(
      '''
      SELECT * FROM (
        SELECT id::text AS id, session_id::text AS session_id, role, content, payload, created_at
        FROM chat_messages WHERE session_id = @s::uuid ORDER BY created_at DESC LIMIT @limit
      ) m ORDER BY created_at
      ''',
      {'s': sessionId, 'limit': limit},
    );
    return [for (final r in rows) _message(r)];
  }

  /// Guarda mensajes (idempotente por ID para la cola offline).
  Future<List<ChatMessage>> append(String me, String sessionId, List<ChatMessage> messages) async {
    await _requireSession(me, sessionId);
    if (messages.length > 50) throw const ApiException.badRequest('Demasiados mensajes.');
    return db.transaction((tx) async {
      final saved = <ChatMessage>[];
      for (final m in messages) {
        if (!Validators.isUuid(m.id)) throw const ApiException.badRequest('Mensaje no válido.');
        final content = m.content.length > maxContentLength
            ? m.content.substring(0, maxContentLength)
            : m.content;
        await tx.execute(
          '''
          INSERT INTO chat_messages (id, session_id, role, content, payload, created_at)
          VALUES (@id::uuid, @s::uuid, @role, @content, @payload::jsonb, @at)
          ON CONFLICT (id) DO NOTHING
          ''',
          {
            'id': m.id,
            's': sessionId,
            'role': m.role.wire,
            'content': content,
            'payload': jsonParam(m.payload),
            'at': m.createdAt,
          },
        );
        saved.add(m);
      }
      await tx.execute('UPDATE chat_sessions SET updated_at = now() WHERE id = @s::uuid', {'s': sessionId});
      return saved;
    });
  }

  Future<void> deleteSession(String me, String sessionId) async {
    final deleted = await db.execute(
      'DELETE FROM chat_sessions WHERE id = @s::uuid AND user_id = @me::uuid',
      {'s': sessionId, 'me': me},
    );
    if (deleted == 0) throw const ApiException.notFound('No encontramos esa conversación.');
  }

  Future<ChatSession> _requireSession(String me, String id) async {
    final row = await db.one(
      'SELECT id::text AS id, title, created_at, updated_at FROM chat_sessions '
      'WHERE id = @id::uuid AND user_id = @me::uuid',
      {'id': id, 'me': me},
    );
    if (row == null) throw const ApiException.notFound('No encontramos esa conversación.');
    return _session(row);
  }

  static String _title(String? title) {
    final t = title?.trim() ?? '';
    if (t.isEmpty) return 'Asistente';
    return t.length > 60 ? t.substring(0, 60) : t;
  }

  static ChatSession _session(Row r) => ChatSession(
        id: r['id'] as String,
        title: r['title'] as String,
        createdAt: r['created_at'] as DateTime,
        updatedAt: r['updated_at'] as DateTime,
      );

  static ChatMessage _message(Row r) => ChatMessage(
        id: r['id'] as String,
        sessionId: r['session_id'] as String,
        role: ChatRole.fromWire(r['role'] as String),
        content: r['content'] as String,
        payload: r['payload'] == null ? null : Map<String, dynamic>.from(r['payload'] as Map),
        createdAt: r['created_at'] as DateTime,
      );
}
