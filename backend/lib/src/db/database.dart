import 'dart:convert';

import 'package:postgres/postgres.dart';

typedef Row = Map<String, dynamic>;

/// Ejecutor de consultas: el pool completo o una transacción.
///
/// Las consultas usan parámetros con nombre (`@id`); nunca se concatenan
/// valores en el SQL.
abstract class Db {
  Future<List<Row>> query(String sql, [Map<String, Object?> params = const {}]);

  Future<Row?> one(String sql, [Map<String, Object?> params = const {}]) async {
    final rows = await query(sql, params);
    return rows.isEmpty ? null : rows.first;
  }

  /// Ejecuta y devuelve el número de filas afectadas.
  Future<int> execute(String sql, [Map<String, Object?> params = const {}]);

  /// Ejecuta [fn] en una transacción (si ya estamos en una, la reutiliza).
  Future<T> transaction<T>(Future<T> Function(Db tx) fn);
}

/// Serializa un valor como `jsonb` (usar con `@param::jsonb`).
String? jsonParam(Object? value) => value == null ? null : jsonEncode(value);

class Database extends Db {
  final Pool _pool;

  Database(this._pool);

  factory Database.connect(String url, {int maxConnections = 10}) {
    final uri = Uri.parse(url);
    final userInfo = uri.userInfo.split(':');
    final sslMode = switch (uri.queryParameters['sslmode']) {
      'disable' => SslMode.disable,
      'verify-full' => SslMode.verifyFull,
      _ => SslMode.require,
    };
    final pool = Pool.withEndpoints(
      [
        Endpoint(
          host: uri.host,
          port: uri.hasPort ? uri.port : 5432,
          database: uri.pathSegments.isEmpty ? 'postgres' : uri.pathSegments.first,
          username: Uri.decodeComponent(userInfo.first),
          password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null,
        ),
      ],
      settings: PoolSettings(
        maxConnectionCount: maxConnections,
        sslMode: sslMode,
        timeZone: 'UTC',
        queryTimeout: const Duration(seconds: 30),
      ),
    );
    return Database(pool);
  }

  @override
  Future<List<Row>> query(String sql, [Map<String, Object?> params = const {}]) async {
    final result = await _pool.execute(Sql.named(sql), parameters: params);
    return [for (final row in result) row.toColumnMap()];
  }

  @override
  Future<int> execute(String sql, [Map<String, Object?> params = const {}]) async {
    final result = await _pool.execute(Sql.named(sql), parameters: params);
    return result.affectedRows;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Db tx) fn) =>
      _pool.runTx((session) => fn(_TxDb(session)));

  Future<void> close() => _pool.close();
}

class _TxDb extends Db {
  final TxSession _session;
  _TxDb(this._session);

  @override
  Future<List<Row>> query(String sql, [Map<String, Object?> params = const {}]) async {
    final result = await _session.execute(Sql.named(sql), parameters: params);
    return [for (final row in result) row.toColumnMap()];
  }

  @override
  Future<int> execute(String sql, [Map<String, Object?> params = const {}]) async {
    final result = await _session.execute(Sql.named(sql), parameters: params);
    return result.affectedRows;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Db tx) fn) => fn(this);
}

/// Código de error de PostgreSQL de una violación de unicidad.
bool isUniqueViolation(Object error, [String? constraint]) =>
    error is ServerException &&
    error.code == '23505' &&
    (constraint == null || error.constraintName == constraint);
