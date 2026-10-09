// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalAlarmsTable extends LocalAlarms
    with TableInfo<$LocalAlarmsTable, LocalAlarm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAlarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatorIdMeta = const VerificationMeta(
    'creatorId',
  );
  @override
  late final GeneratedColumn<String> creatorId = GeneratedColumn<String>(
    'creator_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextOccurrenceMsMeta = const VerificationMeta(
    'nextOccurrenceMs',
  );
  @override
  late final GeneratedColumn<int> nextOccurrenceMs = GeneratedColumn<int>(
    'next_occurrence_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    json,
    creatorId,
    nextOccurrenceMs,
    deleted,
    pendingSync,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_alarms';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAlarm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('creator_id')) {
      context.handle(
        _creatorIdMeta,
        creatorId.isAcceptableOrUnknown(data['creator_id']!, _creatorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_creatorIdMeta);
    }
    if (data.containsKey('next_occurrence_ms')) {
      context.handle(
        _nextOccurrenceMsMeta,
        nextOccurrenceMs.isAcceptableOrUnknown(
          data['next_occurrence_ms']!,
          _nextOccurrenceMsMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAlarm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAlarm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      creatorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_id'],
      )!,
      nextOccurrenceMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_occurrence_ms'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $LocalAlarmsTable createAlias(String alias) {
    return $LocalAlarmsTable(attachedDatabase, alias);
  }
}

class LocalAlarm extends DataClass implements Insertable<LocalAlarm> {
  final String id;
  final String json;
  final String creatorId;
  final int? nextOccurrenceMs;
  final bool deleted;

  /// Hay cambios locales aún no confirmados por el servidor.
  final bool pendingSync;
  final int updatedAtMs;
  const LocalAlarm({
    required this.id,
    required this.json,
    required this.creatorId,
    this.nextOccurrenceMs,
    required this.deleted,
    required this.pendingSync,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    map['creator_id'] = Variable<String>(creatorId);
    if (!nullToAbsent || nextOccurrenceMs != null) {
      map['next_occurrence_ms'] = Variable<int>(nextOccurrenceMs);
    }
    map['deleted'] = Variable<bool>(deleted);
    map['pending_sync'] = Variable<bool>(pendingSync);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  LocalAlarmsCompanion toCompanion(bool nullToAbsent) {
    return LocalAlarmsCompanion(
      id: Value(id),
      json: Value(json),
      creatorId: Value(creatorId),
      nextOccurrenceMs: nextOccurrenceMs == null && nullToAbsent
          ? const Value.absent()
          : Value(nextOccurrenceMs),
      deleted: Value(deleted),
      pendingSync: Value(pendingSync),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory LocalAlarm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAlarm(
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      creatorId: serializer.fromJson<String>(json['creatorId']),
      nextOccurrenceMs: serializer.fromJson<int?>(json['nextOccurrenceMs']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
      'creatorId': serializer.toJson<String>(creatorId),
      'nextOccurrenceMs': serializer.toJson<int?>(nextOccurrenceMs),
      'deleted': serializer.toJson<bool>(deleted),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  LocalAlarm copyWith({
    String? id,
    String? json,
    String? creatorId,
    Value<int?> nextOccurrenceMs = const Value.absent(),
    bool? deleted,
    bool? pendingSync,
    int? updatedAtMs,
  }) => LocalAlarm(
    id: id ?? this.id,
    json: json ?? this.json,
    creatorId: creatorId ?? this.creatorId,
    nextOccurrenceMs: nextOccurrenceMs.present
        ? nextOccurrenceMs.value
        : this.nextOccurrenceMs,
    deleted: deleted ?? this.deleted,
    pendingSync: pendingSync ?? this.pendingSync,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  LocalAlarm copyWithCompanion(LocalAlarmsCompanion data) {
    return LocalAlarm(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      creatorId: data.creatorId.present ? data.creatorId.value : this.creatorId,
      nextOccurrenceMs: data.nextOccurrenceMs.present
          ? data.nextOccurrenceMs.value
          : this.nextOccurrenceMs,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAlarm(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('creatorId: $creatorId, ')
          ..write('nextOccurrenceMs: $nextOccurrenceMs, ')
          ..write('deleted: $deleted, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    json,
    creatorId,
    nextOccurrenceMs,
    deleted,
    pendingSync,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAlarm &&
          other.id == this.id &&
          other.json == this.json &&
          other.creatorId == this.creatorId &&
          other.nextOccurrenceMs == this.nextOccurrenceMs &&
          other.deleted == this.deleted &&
          other.pendingSync == this.pendingSync &&
          other.updatedAtMs == this.updatedAtMs);
}

class LocalAlarmsCompanion extends UpdateCompanion<LocalAlarm> {
  final Value<String> id;
  final Value<String> json;
  final Value<String> creatorId;
  final Value<int?> nextOccurrenceMs;
  final Value<bool> deleted;
  final Value<bool> pendingSync;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const LocalAlarmsCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.creatorId = const Value.absent(),
    this.nextOccurrenceMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAlarmsCompanion.insert({
    required String id,
    required String json,
    required String creatorId,
    this.nextOccurrenceMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.pendingSync = const Value.absent(),
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       json = Value(json),
       creatorId = Value(creatorId),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<LocalAlarm> custom({
    Expression<String>? id,
    Expression<String>? json,
    Expression<String>? creatorId,
    Expression<int>? nextOccurrenceMs,
    Expression<bool>? deleted,
    Expression<bool>? pendingSync,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (creatorId != null) 'creator_id': creatorId,
      if (nextOccurrenceMs != null) 'next_occurrence_ms': nextOccurrenceMs,
      if (deleted != null) 'deleted': deleted,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAlarmsCompanion copyWith({
    Value<String>? id,
    Value<String>? json,
    Value<String>? creatorId,
    Value<int?>? nextOccurrenceMs,
    Value<bool>? deleted,
    Value<bool>? pendingSync,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return LocalAlarmsCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      creatorId: creatorId ?? this.creatorId,
      nextOccurrenceMs: nextOccurrenceMs ?? this.nextOccurrenceMs,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (creatorId.present) {
      map['creator_id'] = Variable<String>(creatorId.value);
    }
    if (nextOccurrenceMs.present) {
      map['next_occurrence_ms'] = Variable<int>(nextOccurrenceMs.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAlarmsCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('creatorId: $creatorId, ')
          ..write('nextOccurrenceMs: $nextOccurrenceMs, ')
          ..write('deleted: $deleted, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalResponsesTable extends LocalResponses
    with TableInfo<$LocalResponsesTable, LocalResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alarmIdMeta = const VerificationMeta(
    'alarmId',
  );
  @override
  late final GeneratedColumn<String> alarmId = GeneratedColumn<String>(
    'alarm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceMsMeta = const VerificationMeta(
    'occurrenceMs',
  );
  @override
  late final GeneratedColumn<int> occurrenceMs = GeneratedColumn<int>(
    'occurrence_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    alarmId,
    userId,
    occurrenceMs,
    json,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('alarm_id')) {
      context.handle(
        _alarmIdMeta,
        alarmId.isAcceptableOrUnknown(data['alarm_id']!, _alarmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_alarmIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('occurrence_ms')) {
      context.handle(
        _occurrenceMsMeta,
        occurrenceMs.isAcceptableOrUnknown(
          data['occurrence_ms']!,
          _occurrenceMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceMsMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {alarmId, userId, occurrenceMs},
  ];
  @override
  LocalResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalResponse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      alarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      occurrenceMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_ms'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $LocalResponsesTable createAlias(String alias) {
    return $LocalResponsesTable(attachedDatabase, alias);
  }
}

class LocalResponse extends DataClass implements Insertable<LocalResponse> {
  final String id;
  final String alarmId;
  final String userId;
  final int occurrenceMs;
  final String json;
  const LocalResponse({
    required this.id,
    required this.alarmId,
    required this.userId,
    required this.occurrenceMs,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['alarm_id'] = Variable<String>(alarmId);
    map['user_id'] = Variable<String>(userId);
    map['occurrence_ms'] = Variable<int>(occurrenceMs);
    map['json'] = Variable<String>(json);
    return map;
  }

  LocalResponsesCompanion toCompanion(bool nullToAbsent) {
    return LocalResponsesCompanion(
      id: Value(id),
      alarmId: Value(alarmId),
      userId: Value(userId),
      occurrenceMs: Value(occurrenceMs),
      json: Value(json),
    );
  }

  factory LocalResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalResponse(
      id: serializer.fromJson<String>(json['id']),
      alarmId: serializer.fromJson<String>(json['alarmId']),
      userId: serializer.fromJson<String>(json['userId']),
      occurrenceMs: serializer.fromJson<int>(json['occurrenceMs']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'alarmId': serializer.toJson<String>(alarmId),
      'userId': serializer.toJson<String>(userId),
      'occurrenceMs': serializer.toJson<int>(occurrenceMs),
      'json': serializer.toJson<String>(json),
    };
  }

  LocalResponse copyWith({
    String? id,
    String? alarmId,
    String? userId,
    int? occurrenceMs,
    String? json,
  }) => LocalResponse(
    id: id ?? this.id,
    alarmId: alarmId ?? this.alarmId,
    userId: userId ?? this.userId,
    occurrenceMs: occurrenceMs ?? this.occurrenceMs,
    json: json ?? this.json,
  );
  LocalResponse copyWithCompanion(LocalResponsesCompanion data) {
    return LocalResponse(
      id: data.id.present ? data.id.value : this.id,
      alarmId: data.alarmId.present ? data.alarmId.value : this.alarmId,
      userId: data.userId.present ? data.userId.value : this.userId,
      occurrenceMs: data.occurrenceMs.present
          ? data.occurrenceMs.value
          : this.occurrenceMs,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalResponse(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('userId: $userId, ')
          ..write('occurrenceMs: $occurrenceMs, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, alarmId, userId, occurrenceMs, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalResponse &&
          other.id == this.id &&
          other.alarmId == this.alarmId &&
          other.userId == this.userId &&
          other.occurrenceMs == this.occurrenceMs &&
          other.json == this.json);
}

class LocalResponsesCompanion extends UpdateCompanion<LocalResponse> {
  final Value<String> id;
  final Value<String> alarmId;
  final Value<String> userId;
  final Value<int> occurrenceMs;
  final Value<String> json;
  final Value<int> rowid;
  const LocalResponsesCompanion({
    this.id = const Value.absent(),
    this.alarmId = const Value.absent(),
    this.userId = const Value.absent(),
    this.occurrenceMs = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalResponsesCompanion.insert({
    required String id,
    required String alarmId,
    required String userId,
    required int occurrenceMs,
    required String json,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       alarmId = Value(alarmId),
       userId = Value(userId),
       occurrenceMs = Value(occurrenceMs),
       json = Value(json);
  static Insertable<LocalResponse> custom({
    Expression<String>? id,
    Expression<String>? alarmId,
    Expression<String>? userId,
    Expression<int>? occurrenceMs,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alarmId != null) 'alarm_id': alarmId,
      if (userId != null) 'user_id': userId,
      if (occurrenceMs != null) 'occurrence_ms': occurrenceMs,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalResponsesCompanion copyWith({
    Value<String>? id,
    Value<String>? alarmId,
    Value<String>? userId,
    Value<int>? occurrenceMs,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return LocalResponsesCompanion(
      id: id ?? this.id,
      alarmId: alarmId ?? this.alarmId,
      userId: userId ?? this.userId,
      occurrenceMs: occurrenceMs ?? this.occurrenceMs,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (alarmId.present) {
      map['alarm_id'] = Variable<String>(alarmId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (occurrenceMs.present) {
      map['occurrence_ms'] = Variable<int>(occurrenceMs.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalResponsesCompanion(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('userId: $userId, ')
          ..write('occurrenceMs: $occurrenceMs, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNotificationsTable extends LocalNotifications
    with TableInfo<$LocalNotificationsTable, LocalNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
    'read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, json, createdAtMs, read];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNotification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('read')) {
      context.handle(
        _readMeta,
        read.isAcceptableOrUnknown(data['read']!, _readMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNotification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      read: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read'],
      )!,
    );
  }

  @override
  $LocalNotificationsTable createAlias(String alias) {
    return $LocalNotificationsTable(attachedDatabase, alias);
  }
}

class LocalNotification extends DataClass
    implements Insertable<LocalNotification> {
  final String id;
  final String json;
  final int createdAtMs;
  final bool read;
  const LocalNotification({
    required this.id,
    required this.json,
    required this.createdAtMs,
    required this.read,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['read'] = Variable<bool>(read);
    return map;
  }

  LocalNotificationsCompanion toCompanion(bool nullToAbsent) {
    return LocalNotificationsCompanion(
      id: Value(id),
      json: Value(json),
      createdAtMs: Value(createdAtMs),
      read: Value(read),
    );
  }

  factory LocalNotification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNotification(
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      read: serializer.fromJson<bool>(json['read']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'read': serializer.toJson<bool>(read),
    };
  }

  LocalNotification copyWith({
    String? id,
    String? json,
    int? createdAtMs,
    bool? read,
  }) => LocalNotification(
    id: id ?? this.id,
    json: json ?? this.json,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    read: read ?? this.read,
  );
  LocalNotification copyWithCompanion(LocalNotificationsCompanion data) {
    return LocalNotification(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      read: data.read.present ? data.read.value : this.read,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotification(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('read: $read')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, createdAtMs, read);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNotification &&
          other.id == this.id &&
          other.json == this.json &&
          other.createdAtMs == this.createdAtMs &&
          other.read == this.read);
}

class LocalNotificationsCompanion extends UpdateCompanion<LocalNotification> {
  final Value<String> id;
  final Value<String> json;
  final Value<int> createdAtMs;
  final Value<bool> read;
  final Value<int> rowid;
  const LocalNotificationsCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.read = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotificationsCompanion.insert({
    required String id,
    required String json,
    required int createdAtMs,
    this.read = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       json = Value(json),
       createdAtMs = Value(createdAtMs);
  static Insertable<LocalNotification> custom({
    Expression<String>? id,
    Expression<String>? json,
    Expression<int>? createdAtMs,
    Expression<bool>? read,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (read != null) 'read': read,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? json,
    Value<int>? createdAtMs,
    Value<bool>? read,
    Value<int>? rowid,
  }) {
    return LocalNotificationsCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      read: read ?? this.read,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('read: $read, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValue extends DataClass implements Insertable<KeyValue> {
  final String key;
  final String value;
  const KeyValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValue copyWith({String? key, String? value}) =>
      KeyValue(key: key ?? this.key, value: value ?? this.value);
  KeyValue copyWithCompanion(KeyValuesCompanion data) {
    return KeyValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValue && other.key == this.key && other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValue> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    entityId,
    payload,
    createdAtMs,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;
  final String kind;
  final String entityId;
  final String payload;
  final int createdAtMs;
  final int attempts;
  final String? lastError;
  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.createdAtMs,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      entityId: Value(entityId),
      payload: Value(payload),
      createdAtMs: Value(createdAtMs),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxEntry copyWith({
    int? id,
    String? kind,
    String? entityId,
    String? payload,
    int? createdAtMs,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxEntry(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    entityId,
    payload,
    createdAtMs,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.createdAtMs == this.createdAtMs &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<int> createdAtMs;
  final Value<int> attempts;
  final Value<String?> lastError;
  const OutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String entityId,
    required String payload,
    required int createdAtMs,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : kind = Value(kind),
       entityId = Value(entityId),
       payload = Value(payload),
       createdAtMs = Value(createdAtMs);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<int>? createdAtMs,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? entityId,
    Value<String>? payload,
    Value<int>? createdAtMs,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return OutboxEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $LocalChatMessagesTable extends LocalChatMessages
    with TableInfo<$LocalChatMessagesTable, LocalChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    role,
    content,
    payload,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $LocalChatMessagesTable createAlias(String alias) {
    return $LocalChatMessagesTable(attachedDatabase, alias);
  }
}

class LocalChatMessage extends DataClass
    implements Insertable<LocalChatMessage> {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final String? payload;
  final int createdAtMs;
  const LocalChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.payload,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  LocalChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalChatMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory LocalChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChatMessage(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'payload': serializer.toJson<String?>(payload),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  LocalChatMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    Value<String?> payload = const Value.absent(),
    int? createdAtMs,
  }) => LocalChatMessage(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    role: role ?? this.role,
    content: content ?? this.content,
    payload: payload.present ? payload.value : this.payload,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  LocalChatMessage copyWithCompanion(LocalChatMessagesCompanion data) {
    return LocalChatMessage(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChatMessage(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('payload: $payload, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, role, content, payload, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChatMessage &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.role == this.role &&
          other.content == this.content &&
          other.payload == this.payload &&
          other.createdAtMs == this.createdAtMs);
}

class LocalChatMessagesCompanion extends UpdateCompanion<LocalChatMessage> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> role;
  final Value<String> content;
  final Value<String?> payload;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const LocalChatMessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalChatMessagesCompanion.insert({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    this.payload = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       role = Value(role),
       content = Value(content),
       createdAtMs = Value(createdAtMs);
  static Insertable<LocalChatMessage> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? payload,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (payload != null) 'payload': payload,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? role,
    Value<String>? content,
    Value<String?>? payload,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return LocalChatMessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      payload: payload ?? this.payload,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('payload: $payload, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduledNativeAlarmsTable extends ScheduledNativeAlarms
    with TableInfo<$ScheduledNativeAlarmsTable, ScheduledNativeAlarm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledNativeAlarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nativeIdMeta = const VerificationMeta(
    'nativeId',
  );
  @override
  late final GeneratedColumn<int> nativeId = GeneratedColumn<int>(
    'native_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alarmIdMeta = const VerificationMeta(
    'alarmId',
  );
  @override
  late final GeneratedColumn<String> alarmId = GeneratedColumn<String>(
    'alarm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceMsMeta = const VerificationMeta(
    'occurrenceMs',
  );
  @override
  late final GeneratedColumn<int> occurrenceMs = GeneratedColumn<int>(
    'occurrence_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ringAtMsMeta = const VerificationMeta(
    'ringAtMs',
  );
  @override
  late final GeneratedColumn<int> ringAtMs = GeneratedColumn<int>(
    'ring_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    nativeId,
    alarmId,
    occurrenceMs,
    ringAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_native_alarms';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledNativeAlarm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('native_id')) {
      context.handle(
        _nativeIdMeta,
        nativeId.isAcceptableOrUnknown(data['native_id']!, _nativeIdMeta),
      );
    }
    if (data.containsKey('alarm_id')) {
      context.handle(
        _alarmIdMeta,
        alarmId.isAcceptableOrUnknown(data['alarm_id']!, _alarmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_alarmIdMeta);
    }
    if (data.containsKey('occurrence_ms')) {
      context.handle(
        _occurrenceMsMeta,
        occurrenceMs.isAcceptableOrUnknown(
          data['occurrence_ms']!,
          _occurrenceMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceMsMeta);
    }
    if (data.containsKey('ring_at_ms')) {
      context.handle(
        _ringAtMsMeta,
        ringAtMs.isAcceptableOrUnknown(data['ring_at_ms']!, _ringAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_ringAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nativeId};
  @override
  ScheduledNativeAlarm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledNativeAlarm(
      nativeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}native_id'],
      )!,
      alarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_id'],
      )!,
      occurrenceMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_ms'],
      )!,
      ringAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ring_at_ms'],
      )!,
    );
  }

  @override
  $ScheduledNativeAlarmsTable createAlias(String alias) {
    return $ScheduledNativeAlarmsTable(attachedDatabase, alias);
  }
}

class ScheduledNativeAlarm extends DataClass
    implements Insertable<ScheduledNativeAlarm> {
  final int nativeId;
  final String alarmId;
  final int occurrenceMs;

  /// Momento en que sonará (puede diferir de la ocurrencia si se pospuso).
  final int ringAtMs;
  const ScheduledNativeAlarm({
    required this.nativeId,
    required this.alarmId,
    required this.occurrenceMs,
    required this.ringAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['native_id'] = Variable<int>(nativeId);
    map['alarm_id'] = Variable<String>(alarmId);
    map['occurrence_ms'] = Variable<int>(occurrenceMs);
    map['ring_at_ms'] = Variable<int>(ringAtMs);
    return map;
  }

  ScheduledNativeAlarmsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledNativeAlarmsCompanion(
      nativeId: Value(nativeId),
      alarmId: Value(alarmId),
      occurrenceMs: Value(occurrenceMs),
      ringAtMs: Value(ringAtMs),
    );
  }

  factory ScheduledNativeAlarm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledNativeAlarm(
      nativeId: serializer.fromJson<int>(json['nativeId']),
      alarmId: serializer.fromJson<String>(json['alarmId']),
      occurrenceMs: serializer.fromJson<int>(json['occurrenceMs']),
      ringAtMs: serializer.fromJson<int>(json['ringAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nativeId': serializer.toJson<int>(nativeId),
      'alarmId': serializer.toJson<String>(alarmId),
      'occurrenceMs': serializer.toJson<int>(occurrenceMs),
      'ringAtMs': serializer.toJson<int>(ringAtMs),
    };
  }

  ScheduledNativeAlarm copyWith({
    int? nativeId,
    String? alarmId,
    int? occurrenceMs,
    int? ringAtMs,
  }) => ScheduledNativeAlarm(
    nativeId: nativeId ?? this.nativeId,
    alarmId: alarmId ?? this.alarmId,
    occurrenceMs: occurrenceMs ?? this.occurrenceMs,
    ringAtMs: ringAtMs ?? this.ringAtMs,
  );
  ScheduledNativeAlarm copyWithCompanion(ScheduledNativeAlarmsCompanion data) {
    return ScheduledNativeAlarm(
      nativeId: data.nativeId.present ? data.nativeId.value : this.nativeId,
      alarmId: data.alarmId.present ? data.alarmId.value : this.alarmId,
      occurrenceMs: data.occurrenceMs.present
          ? data.occurrenceMs.value
          : this.occurrenceMs,
      ringAtMs: data.ringAtMs.present ? data.ringAtMs.value : this.ringAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNativeAlarm(')
          ..write('nativeId: $nativeId, ')
          ..write('alarmId: $alarmId, ')
          ..write('occurrenceMs: $occurrenceMs, ')
          ..write('ringAtMs: $ringAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(nativeId, alarmId, occurrenceMs, ringAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledNativeAlarm &&
          other.nativeId == this.nativeId &&
          other.alarmId == this.alarmId &&
          other.occurrenceMs == this.occurrenceMs &&
          other.ringAtMs == this.ringAtMs);
}

class ScheduledNativeAlarmsCompanion
    extends UpdateCompanion<ScheduledNativeAlarm> {
  final Value<int> nativeId;
  final Value<String> alarmId;
  final Value<int> occurrenceMs;
  final Value<int> ringAtMs;
  const ScheduledNativeAlarmsCompanion({
    this.nativeId = const Value.absent(),
    this.alarmId = const Value.absent(),
    this.occurrenceMs = const Value.absent(),
    this.ringAtMs = const Value.absent(),
  });
  ScheduledNativeAlarmsCompanion.insert({
    this.nativeId = const Value.absent(),
    required String alarmId,
    required int occurrenceMs,
    required int ringAtMs,
  }) : alarmId = Value(alarmId),
       occurrenceMs = Value(occurrenceMs),
       ringAtMs = Value(ringAtMs);
  static Insertable<ScheduledNativeAlarm> custom({
    Expression<int>? nativeId,
    Expression<String>? alarmId,
    Expression<int>? occurrenceMs,
    Expression<int>? ringAtMs,
  }) {
    return RawValuesInsertable({
      if (nativeId != null) 'native_id': nativeId,
      if (alarmId != null) 'alarm_id': alarmId,
      if (occurrenceMs != null) 'occurrence_ms': occurrenceMs,
      if (ringAtMs != null) 'ring_at_ms': ringAtMs,
    });
  }

  ScheduledNativeAlarmsCompanion copyWith({
    Value<int>? nativeId,
    Value<String>? alarmId,
    Value<int>? occurrenceMs,
    Value<int>? ringAtMs,
  }) {
    return ScheduledNativeAlarmsCompanion(
      nativeId: nativeId ?? this.nativeId,
      alarmId: alarmId ?? this.alarmId,
      occurrenceMs: occurrenceMs ?? this.occurrenceMs,
      ringAtMs: ringAtMs ?? this.ringAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nativeId.present) {
      map['native_id'] = Variable<int>(nativeId.value);
    }
    if (alarmId.present) {
      map['alarm_id'] = Variable<String>(alarmId.value);
    }
    if (occurrenceMs.present) {
      map['occurrence_ms'] = Variable<int>(occurrenceMs.value);
    }
    if (ringAtMs.present) {
      map['ring_at_ms'] = Variable<int>(ringAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNativeAlarmsCompanion(')
          ..write('nativeId: $nativeId, ')
          ..write('alarmId: $alarmId, ')
          ..write('occurrenceMs: $occurrenceMs, ')
          ..write('ringAtMs: $ringAtMs')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalAlarmsTable localAlarms = $LocalAlarmsTable(this);
  late final $LocalResponsesTable localResponses = $LocalResponsesTable(this);
  late final $LocalNotificationsTable localNotifications =
      $LocalNotificationsTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  late final $LocalChatMessagesTable localChatMessages =
      $LocalChatMessagesTable(this);
  late final $ScheduledNativeAlarmsTable scheduledNativeAlarms =
      $ScheduledNativeAlarmsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localAlarms,
    localResponses,
    localNotifications,
    keyValues,
    outboxEntries,
    localChatMessages,
    scheduledNativeAlarms,
  ];
}

typedef $$LocalAlarmsTableCreateCompanionBuilder =
    LocalAlarmsCompanion Function({
      required String id,
      required String json,
      required String creatorId,
      Value<int?> nextOccurrenceMs,
      Value<bool> deleted,
      Value<bool> pendingSync,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$LocalAlarmsTableUpdateCompanionBuilder =
    LocalAlarmsCompanion Function({
      Value<String> id,
      Value<String> json,
      Value<String> creatorId,
      Value<int?> nextOccurrenceMs,
      Value<bool> deleted,
      Value<bool> pendingSync,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$LocalAlarmsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAlarmsTable> {
  $$LocalAlarmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorId => $composableBuilder(
    column: $table.creatorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextOccurrenceMs => $composableBuilder(
    column: $table.nextOccurrenceMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAlarmsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAlarmsTable> {
  $$LocalAlarmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorId => $composableBuilder(
    column: $table.creatorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextOccurrenceMs => $composableBuilder(
    column: $table.nextOccurrenceMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAlarmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAlarmsTable> {
  $$LocalAlarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get creatorId =>
      $composableBuilder(column: $table.creatorId, builder: (column) => column);

  GeneratedColumn<int> get nextOccurrenceMs => $composableBuilder(
    column: $table.nextOccurrenceMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$LocalAlarmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAlarmsTable,
          LocalAlarm,
          $$LocalAlarmsTableFilterComposer,
          $$LocalAlarmsTableOrderingComposer,
          $$LocalAlarmsTableAnnotationComposer,
          $$LocalAlarmsTableCreateCompanionBuilder,
          $$LocalAlarmsTableUpdateCompanionBuilder,
          (
            LocalAlarm,
            BaseReferences<_$AppDatabase, $LocalAlarmsTable, LocalAlarm>,
          ),
          LocalAlarm,
          PrefetchHooks Function()
        > {
  $$LocalAlarmsTableTableManager(_$AppDatabase db, $LocalAlarmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAlarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAlarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAlarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<String> creatorId = const Value.absent(),
                Value<int?> nextOccurrenceMs = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAlarmsCompanion(
                id: id,
                json: json,
                creatorId: creatorId,
                nextOccurrenceMs: nextOccurrenceMs,
                deleted: deleted,
                pendingSync: pendingSync,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String json,
                required String creatorId,
                Value<int?> nextOccurrenceMs = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LocalAlarmsCompanion.insert(
                id: id,
                json: json,
                creatorId: creatorId,
                nextOccurrenceMs: nextOccurrenceMs,
                deleted: deleted,
                pendingSync: pendingSync,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAlarmsTable, LocalAlarm>(table),
                  BaseReferences<_$AppDatabase, $LocalAlarmsTable, LocalAlarm>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAlarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAlarmsTable,
      LocalAlarm,
      $$LocalAlarmsTableFilterComposer,
      $$LocalAlarmsTableOrderingComposer,
      $$LocalAlarmsTableAnnotationComposer,
      $$LocalAlarmsTableCreateCompanionBuilder,
      $$LocalAlarmsTableUpdateCompanionBuilder,
      (
        LocalAlarm,
        BaseReferences<_$AppDatabase, $LocalAlarmsTable, LocalAlarm>,
      ),
      LocalAlarm,
      PrefetchHooks Function()
    >;
typedef $$LocalResponsesTableCreateCompanionBuilder =
    LocalResponsesCompanion Function({
      required String id,
      required String alarmId,
      required String userId,
      required int occurrenceMs,
      required String json,
      Value<int> rowid,
    });
typedef $$LocalResponsesTableUpdateCompanionBuilder =
    LocalResponsesCompanion Function({
      Value<String> id,
      Value<String> alarmId,
      Value<String> userId,
      Value<int> occurrenceMs,
      Value<String> json,
      Value<int> rowid,
    });

class $$LocalResponsesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalResponsesTable> {
  $$LocalResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalResponsesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalResponsesTable> {
  $$LocalResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalResponsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalResponsesTable> {
  $$LocalResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alarmId =>
      $composableBuilder(column: $table.alarmId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$LocalResponsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalResponsesTable,
          LocalResponse,
          $$LocalResponsesTableFilterComposer,
          $$LocalResponsesTableOrderingComposer,
          $$LocalResponsesTableAnnotationComposer,
          $$LocalResponsesTableCreateCompanionBuilder,
          $$LocalResponsesTableUpdateCompanionBuilder,
          (
            LocalResponse,
            BaseReferences<_$AppDatabase, $LocalResponsesTable, LocalResponse>,
          ),
          LocalResponse,
          PrefetchHooks Function()
        > {
  $$LocalResponsesTableTableManager(
    _$AppDatabase db,
    $LocalResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> alarmId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> occurrenceMs = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalResponsesCompanion(
                id: id,
                alarmId: alarmId,
                userId: userId,
                occurrenceMs: occurrenceMs,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String alarmId,
                required String userId,
                required int occurrenceMs,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => LocalResponsesCompanion.insert(
                id: id,
                alarmId: alarmId,
                userId: userId,
                occurrenceMs: occurrenceMs,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalResponsesTable, LocalResponse>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalResponsesTable,
                    LocalResponse
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalResponsesTable,
      LocalResponse,
      $$LocalResponsesTableFilterComposer,
      $$LocalResponsesTableOrderingComposer,
      $$LocalResponsesTableAnnotationComposer,
      $$LocalResponsesTableCreateCompanionBuilder,
      $$LocalResponsesTableUpdateCompanionBuilder,
      (
        LocalResponse,
        BaseReferences<_$AppDatabase, $LocalResponsesTable, LocalResponse>,
      ),
      LocalResponse,
      PrefetchHooks Function()
    >;
typedef $$LocalNotificationsTableCreateCompanionBuilder =
    LocalNotificationsCompanion Function({
      required String id,
      required String json,
      required int createdAtMs,
      Value<bool> read,
      Value<int> rowid,
    });
typedef $$LocalNotificationsTableUpdateCompanionBuilder =
    LocalNotificationsCompanion Function({
      Value<String> id,
      Value<String> json,
      Value<int> createdAtMs,
      Value<bool> read,
      Value<int> rowid,
    });

class $$LocalNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalNotificationsTable> {
  $$LocalNotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalNotificationsTable> {
  $$LocalNotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalNotificationsTable> {
  $$LocalNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);
}

class $$LocalNotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalNotificationsTable,
          LocalNotification,
          $$LocalNotificationsTableFilterComposer,
          $$LocalNotificationsTableOrderingComposer,
          $$LocalNotificationsTableAnnotationComposer,
          $$LocalNotificationsTableCreateCompanionBuilder,
          $$LocalNotificationsTableUpdateCompanionBuilder,
          (
            LocalNotification,
            BaseReferences<
              _$AppDatabase,
              $LocalNotificationsTable,
              LocalNotification
            >,
          ),
          LocalNotification,
          PrefetchHooks Function()
        > {
  $$LocalNotificationsTableTableManager(
    _$AppDatabase db,
    $LocalNotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNotificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotificationsCompanion(
                id: id,
                json: json,
                createdAtMs: createdAtMs,
                read: read,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String json,
                required int createdAtMs,
                Value<bool> read = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotificationsCompanion.insert(
                id: id,
                json: json,
                createdAtMs: createdAtMs,
                read: read,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalNotificationsTable, LocalNotification>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalNotificationsTable,
                    LocalNotification
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalNotificationsTable,
      LocalNotification,
      $$LocalNotificationsTableFilterComposer,
      $$LocalNotificationsTableOrderingComposer,
      $$LocalNotificationsTableAnnotationComposer,
      $$LocalNotificationsTableCreateCompanionBuilder,
      $$LocalNotificationsTableUpdateCompanionBuilder,
      (
        LocalNotification,
        BaseReferences<
          _$AppDatabase,
          $LocalNotificationsTable,
          LocalNotification
        >,
      ),
      LocalNotification,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder =
    KeyValuesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$KeyValuesTableUpdateCompanionBuilder =
    KeyValuesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$KeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValue,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
          KeyValue,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValue>(table),
                  BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValue,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
      KeyValue,
      PrefetchHooks Function()
    >;
typedef $$OutboxEntriesTableCreateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<int> id,
      required String kind,
      required String entityId,
      required String payload,
      required int createdAtMs,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$OutboxEntriesTableUpdateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> entityId,
      Value<String> payload,
      Value<int> createdAtMs,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxEntriesTable,
          OutboxEntry,
          $$OutboxEntriesTableFilterComposer,
          $$OutboxEntriesTableOrderingComposer,
          $$OutboxEntriesTableAnnotationComposer,
          $$OutboxEntriesTableCreateCompanionBuilder,
          $$OutboxEntriesTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxEntriesTableTableManager(_$AppDatabase db, $OutboxEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxEntriesCompanion(
                id: id,
                kind: kind,
                entityId: entityId,
                payload: payload,
                createdAtMs: createdAtMs,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String entityId,
                required String payload,
                required int createdAtMs,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxEntriesCompanion.insert(
                id: id,
                kind: kind,
                entityId: entityId,
                payload: payload,
                createdAtMs: createdAtMs,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxEntriesTable, OutboxEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OutboxEntriesTable,
                    OutboxEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxEntriesTable,
      OutboxEntry,
      $$OutboxEntriesTableFilterComposer,
      $$OutboxEntriesTableOrderingComposer,
      $$OutboxEntriesTableAnnotationComposer,
      $$OutboxEntriesTableCreateCompanionBuilder,
      $$OutboxEntriesTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$LocalChatMessagesTableCreateCompanionBuilder =
    LocalChatMessagesCompanion Function({
      required String id,
      required String sessionId,
      required String role,
      required String content,
      Value<String?> payload,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$LocalChatMessagesTableUpdateCompanionBuilder =
    LocalChatMessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> role,
      Value<String> content,
      Value<String?> payload,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$LocalChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalChatMessagesTable> {
  $$LocalChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalChatMessagesTable> {
  $$LocalChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalChatMessagesTable> {
  $$LocalChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$LocalChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalChatMessagesTable,
          LocalChatMessage,
          $$LocalChatMessagesTableFilterComposer,
          $$LocalChatMessagesTableOrderingComposer,
          $$LocalChatMessagesTableAnnotationComposer,
          $$LocalChatMessagesTableCreateCompanionBuilder,
          $$LocalChatMessagesTableUpdateCompanionBuilder,
          (
            LocalChatMessage,
            BaseReferences<
              _$AppDatabase,
              $LocalChatMessagesTable,
              LocalChatMessage
            >,
          ),
          LocalChatMessage,
          PrefetchHooks Function()
        > {
  $$LocalChatMessagesTableTableManager(
    _$AppDatabase db,
    $LocalChatMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalChatMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalChatMessagesCompanion(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                payload: payload,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String role,
                required String content,
                Value<String?> payload = const Value.absent(),
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LocalChatMessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                payload: payload,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalChatMessagesTable, LocalChatMessage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalChatMessagesTable,
                    LocalChatMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalChatMessagesTable,
      LocalChatMessage,
      $$LocalChatMessagesTableFilterComposer,
      $$LocalChatMessagesTableOrderingComposer,
      $$LocalChatMessagesTableAnnotationComposer,
      $$LocalChatMessagesTableCreateCompanionBuilder,
      $$LocalChatMessagesTableUpdateCompanionBuilder,
      (
        LocalChatMessage,
        BaseReferences<
          _$AppDatabase,
          $LocalChatMessagesTable,
          LocalChatMessage
        >,
      ),
      LocalChatMessage,
      PrefetchHooks Function()
    >;
typedef $$ScheduledNativeAlarmsTableCreateCompanionBuilder =
    ScheduledNativeAlarmsCompanion Function({
      Value<int> nativeId,
      required String alarmId,
      required int occurrenceMs,
      required int ringAtMs,
    });
typedef $$ScheduledNativeAlarmsTableUpdateCompanionBuilder =
    ScheduledNativeAlarmsCompanion Function({
      Value<int> nativeId,
      Value<String> alarmId,
      Value<int> occurrenceMs,
      Value<int> ringAtMs,
    });

class $$ScheduledNativeAlarmsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledNativeAlarmsTable> {
  $$ScheduledNativeAlarmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get nativeId => $composableBuilder(
    column: $table.nativeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ringAtMs => $composableBuilder(
    column: $table.ringAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduledNativeAlarmsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledNativeAlarmsTable> {
  $$ScheduledNativeAlarmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get nativeId => $composableBuilder(
    column: $table.nativeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ringAtMs => $composableBuilder(
    column: $table.ringAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduledNativeAlarmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledNativeAlarmsTable> {
  $$ScheduledNativeAlarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get nativeId =>
      $composableBuilder(column: $table.nativeId, builder: (column) => column);

  GeneratedColumn<String> get alarmId =>
      $composableBuilder(column: $table.alarmId, builder: (column) => column);

  GeneratedColumn<int> get occurrenceMs => $composableBuilder(
    column: $table.occurrenceMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ringAtMs =>
      $composableBuilder(column: $table.ringAtMs, builder: (column) => column);
}

class $$ScheduledNativeAlarmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledNativeAlarmsTable,
          ScheduledNativeAlarm,
          $$ScheduledNativeAlarmsTableFilterComposer,
          $$ScheduledNativeAlarmsTableOrderingComposer,
          $$ScheduledNativeAlarmsTableAnnotationComposer,
          $$ScheduledNativeAlarmsTableCreateCompanionBuilder,
          $$ScheduledNativeAlarmsTableUpdateCompanionBuilder,
          (
            ScheduledNativeAlarm,
            BaseReferences<
              _$AppDatabase,
              $ScheduledNativeAlarmsTable,
              ScheduledNativeAlarm
            >,
          ),
          ScheduledNativeAlarm,
          PrefetchHooks Function()
        > {
  $$ScheduledNativeAlarmsTableTableManager(
    _$AppDatabase db,
    $ScheduledNativeAlarmsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledNativeAlarmsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduledNativeAlarmsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledNativeAlarmsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> nativeId = const Value.absent(),
                Value<String> alarmId = const Value.absent(),
                Value<int> occurrenceMs = const Value.absent(),
                Value<int> ringAtMs = const Value.absent(),
              }) => ScheduledNativeAlarmsCompanion(
                nativeId: nativeId,
                alarmId: alarmId,
                occurrenceMs: occurrenceMs,
                ringAtMs: ringAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> nativeId = const Value.absent(),
                required String alarmId,
                required int occurrenceMs,
                required int ringAtMs,
              }) => ScheduledNativeAlarmsCompanion.insert(
                nativeId: nativeId,
                alarmId: alarmId,
                occurrenceMs: occurrenceMs,
                ringAtMs: ringAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ScheduledNativeAlarmsTable,
                    ScheduledNativeAlarm
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ScheduledNativeAlarmsTable,
                    ScheduledNativeAlarm
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduledNativeAlarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledNativeAlarmsTable,
      ScheduledNativeAlarm,
      $$ScheduledNativeAlarmsTableFilterComposer,
      $$ScheduledNativeAlarmsTableOrderingComposer,
      $$ScheduledNativeAlarmsTableAnnotationComposer,
      $$ScheduledNativeAlarmsTableCreateCompanionBuilder,
      $$ScheduledNativeAlarmsTableUpdateCompanionBuilder,
      (
        ScheduledNativeAlarm,
        BaseReferences<
          _$AppDatabase,
          $ScheduledNativeAlarmsTable,
          ScheduledNativeAlarm
        >,
      ),
      ScheduledNativeAlarm,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalAlarmsTableTableManager get localAlarms =>
      $$LocalAlarmsTableTableManager(_db, _db.localAlarms);
  $$LocalResponsesTableTableManager get localResponses =>
      $$LocalResponsesTableTableManager(_db, _db.localResponses);
  $$LocalNotificationsTableTableManager get localNotifications =>
      $$LocalNotificationsTableTableManager(_db, _db.localNotifications);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
  $$LocalChatMessagesTableTableManager get localChatMessages =>
      $$LocalChatMessagesTableTableManager(_db, _db.localChatMessages);
  $$ScheduledNativeAlarmsTableTableManager get scheduledNativeAlarms =>
      $$ScheduledNativeAlarmsTableTableManager(_db, _db.scheduledNativeAlarms);
}
