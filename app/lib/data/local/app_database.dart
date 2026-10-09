import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Copia local de las alarmas visibles (JSON del contrato de la API) con las
/// columnas necesarias para consultar sin conexión.
class LocalAlarms extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();
  TextColumn get creatorId => text()();
  IntColumn get nextOccurrenceMs => integer().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Hay cambios locales aún no confirmados por el servidor.
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalResponses extends Table {
  TextColumn get id => text()();
  TextColumn get alarmId => text()();
  TextColumn get userId => text()();
  IntColumn get occurrenceMs => integer()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {alarmId, userId, occurrenceMs},
      ];
}

class LocalNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();
  IntColumn get createdAtMs => integer()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Clave/valor: perfil, contactos, grupos, cursor de sincronización...
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Cola de operaciones pendientes de enviar al servidor (modo sin conexión).
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()();
  IntColumn get createdAtMs => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

class LocalChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get payload => text().nullable()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Alarmas programadas en el sistema operativo (id nativo ↔ ocurrencia).
class ScheduledNativeAlarms extends Table {
  IntColumn get nativeId => integer()();
  TextColumn get alarmId => text()();
  IntColumn get occurrenceMs => integer()();

  /// Momento en que sonará (puede diferir de la ocurrencia si se pospuso).
  IntColumn get ringAtMs => integer()();

  @override
  Set<Column> get primaryKey => {nativeId};
}

@DriftDatabase(
  tables: [
    LocalAlarms,
    LocalResponses,
    LocalNotifications,
    KeyValues,
    OutboxEntries,
    LocalChatMessages,
    ScheduledNativeAlarms,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  // Compartida entre isolates: el manejador de push en segundo plano también
  // la usa.
  static QueryExecutor _open() => driftDatabase(
        name: 'ally',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      );

  @override
  int get schemaVersion => 1;

  // ------------------------------------------------------------ clave/valor

  Future<String?> getValue(String key) async =>
      (await (select(keyValues)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setValue(String key, String value) =>
      into(keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));

  Future<void> removeValue(String key) =>
      (delete(keyValues)..where((t) => t.key.equals(key))).go();

  Stream<String?> watchValue(String key) => (select(keyValues)..where((t) => t.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row?.value);

  /// Borra todos los datos locales (cerrar sesión).
  Future<void> clearAll() => transaction(() async {
        for (final table in allTables) {
          await delete(table).go();
        }
      });
}
