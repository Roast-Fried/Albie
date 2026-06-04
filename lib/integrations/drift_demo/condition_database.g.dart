// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'condition_database.dart';

// ignore_for_file: type=lint
class $ConditionLogsTable extends ConditionLogs
    with TableInfo<$ConditionLogsTable, ConditionLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConditionLogsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _loggedOnMeta = const VerificationMeta(
    'loggedOn',
  );
  @override
  late final GeneratedColumn<DateTime> loggedOn = GeneratedColumn<DateTime>(
    'logged_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<int> severity = GeneratedColumn<int>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sleepHoursMeta = const VerificationMeta(
    'sleepHours',
  );
  @override
  late final GeneratedColumn<double> sleepHours = GeneratedColumn<double>(
    'sleep_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    loggedOn,
    severity,
    sleepHours,
    memo,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'condition_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConditionLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('logged_on')) {
      context.handle(
        _loggedOnMeta,
        loggedOn.isAcceptableOrUnknown(data['logged_on']!, _loggedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedOnMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('sleep_hours')) {
      context.handle(
        _sleepHoursMeta,
        sleepHours.isAcceptableOrUnknown(data['sleep_hours']!, _sleepHoursMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConditionLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConditionLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      loggedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_on'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}severity'],
      )!,
      sleepHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_hours'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ConditionLogsTable createAlias(String alias) {
    return $ConditionLogsTable(attachedDatabase, alias);
  }
}

class ConditionLog extends DataClass implements Insertable<ConditionLog> {
  final int id;

  /// 컨디션을 기록한 날짜 (음주 다음날 등).
  final DateTime loggedOn;

  /// 숙취 정도 1(없음)~5(심함).
  final int severity;

  /// 수면 시간(시간). 선택.
  final double? sleepHours;

  /// 메모. 선택.
  final String? memo;
  final DateTime createdAt;
  const ConditionLog({
    required this.id,
    required this.loggedOn,
    required this.severity,
    this.sleepHours,
    this.memo,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['logged_on'] = Variable<DateTime>(loggedOn);
    map['severity'] = Variable<int>(severity);
    if (!nullToAbsent || sleepHours != null) {
      map['sleep_hours'] = Variable<double>(sleepHours);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ConditionLogsCompanion toCompanion(bool nullToAbsent) {
    return ConditionLogsCompanion(
      id: Value(id),
      loggedOn: Value(loggedOn),
      severity: Value(severity),
      sleepHours: sleepHours == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepHours),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      createdAt: Value(createdAt),
    );
  }

  factory ConditionLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConditionLog(
      id: serializer.fromJson<int>(json['id']),
      loggedOn: serializer.fromJson<DateTime>(json['loggedOn']),
      severity: serializer.fromJson<int>(json['severity']),
      sleepHours: serializer.fromJson<double?>(json['sleepHours']),
      memo: serializer.fromJson<String?>(json['memo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'loggedOn': serializer.toJson<DateTime>(loggedOn),
      'severity': serializer.toJson<int>(severity),
      'sleepHours': serializer.toJson<double?>(sleepHours),
      'memo': serializer.toJson<String?>(memo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ConditionLog copyWith({
    int? id,
    DateTime? loggedOn,
    int? severity,
    Value<double?> sleepHours = const Value.absent(),
    Value<String?> memo = const Value.absent(),
    DateTime? createdAt,
  }) => ConditionLog(
    id: id ?? this.id,
    loggedOn: loggedOn ?? this.loggedOn,
    severity: severity ?? this.severity,
    sleepHours: sleepHours.present ? sleepHours.value : this.sleepHours,
    memo: memo.present ? memo.value : this.memo,
    createdAt: createdAt ?? this.createdAt,
  );
  ConditionLog copyWithCompanion(ConditionLogsCompanion data) {
    return ConditionLog(
      id: data.id.present ? data.id.value : this.id,
      loggedOn: data.loggedOn.present ? data.loggedOn.value : this.loggedOn,
      severity: data.severity.present ? data.severity.value : this.severity,
      sleepHours: data.sleepHours.present
          ? data.sleepHours.value
          : this.sleepHours,
      memo: data.memo.present ? data.memo.value : this.memo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConditionLog(')
          ..write('id: $id, ')
          ..write('loggedOn: $loggedOn, ')
          ..write('severity: $severity, ')
          ..write('sleepHours: $sleepHours, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, loggedOn, severity, sleepHours, memo, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConditionLog &&
          other.id == this.id &&
          other.loggedOn == this.loggedOn &&
          other.severity == this.severity &&
          other.sleepHours == this.sleepHours &&
          other.memo == this.memo &&
          other.createdAt == this.createdAt);
}

class ConditionLogsCompanion extends UpdateCompanion<ConditionLog> {
  final Value<int> id;
  final Value<DateTime> loggedOn;
  final Value<int> severity;
  final Value<double?> sleepHours;
  final Value<String?> memo;
  final Value<DateTime> createdAt;
  const ConditionLogsCompanion({
    this.id = const Value.absent(),
    this.loggedOn = const Value.absent(),
    this.severity = const Value.absent(),
    this.sleepHours = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ConditionLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime loggedOn,
    required int severity,
    this.sleepHours = const Value.absent(),
    this.memo = const Value.absent(),
    required DateTime createdAt,
  }) : loggedOn = Value(loggedOn),
       severity = Value(severity),
       createdAt = Value(createdAt);
  static Insertable<ConditionLog> custom({
    Expression<int>? id,
    Expression<DateTime>? loggedOn,
    Expression<int>? severity,
    Expression<double>? sleepHours,
    Expression<String>? memo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (loggedOn != null) 'logged_on': loggedOn,
      if (severity != null) 'severity': severity,
      if (sleepHours != null) 'sleep_hours': sleepHours,
      if (memo != null) 'memo': memo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ConditionLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? loggedOn,
    Value<int>? severity,
    Value<double?>? sleepHours,
    Value<String?>? memo,
    Value<DateTime>? createdAt,
  }) {
    return ConditionLogsCompanion(
      id: id ?? this.id,
      loggedOn: loggedOn ?? this.loggedOn,
      severity: severity ?? this.severity,
      sleepHours: sleepHours ?? this.sleepHours,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (loggedOn.present) {
      map['logged_on'] = Variable<DateTime>(loggedOn.value);
    }
    if (severity.present) {
      map['severity'] = Variable<int>(severity.value);
    }
    if (sleepHours.present) {
      map['sleep_hours'] = Variable<double>(sleepHours.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConditionLogsCompanion(')
          ..write('id: $id, ')
          ..write('loggedOn: $loggedOn, ')
          ..write('severity: $severity, ')
          ..write('sleepHours: $sleepHours, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$ConditionDatabase extends GeneratedDatabase {
  _$ConditionDatabase(QueryExecutor e) : super(e);
  $ConditionDatabaseManager get managers => $ConditionDatabaseManager(this);
  late final $ConditionLogsTable conditionLogs = $ConditionLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [conditionLogs];
}

typedef $$ConditionLogsTableCreateCompanionBuilder =
    ConditionLogsCompanion Function({
      Value<int> id,
      required DateTime loggedOn,
      required int severity,
      Value<double?> sleepHours,
      Value<String?> memo,
      required DateTime createdAt,
    });
typedef $$ConditionLogsTableUpdateCompanionBuilder =
    ConditionLogsCompanion Function({
      Value<int> id,
      Value<DateTime> loggedOn,
      Value<int> severity,
      Value<double?> sleepHours,
      Value<String?> memo,
      Value<DateTime> createdAt,
    });

class $$ConditionLogsTableFilterComposer
    extends Composer<_$ConditionDatabase, $ConditionLogsTable> {
  $$ConditionLogsTableFilterComposer({
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

  ColumnFilters<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepHours => $composableBuilder(
    column: $table.sleepHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConditionLogsTableOrderingComposer
    extends Composer<_$ConditionDatabase, $ConditionLogsTable> {
  $$ConditionLogsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepHours => $composableBuilder(
    column: $table.sleepHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConditionLogsTableAnnotationComposer
    extends Composer<_$ConditionDatabase, $ConditionLogsTable> {
  $$ConditionLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedOn =>
      $composableBuilder(column: $table.loggedOn, builder: (column) => column);

  GeneratedColumn<int> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<double> get sleepHours => $composableBuilder(
    column: $table.sleepHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ConditionLogsTableTableManager
    extends
        RootTableManager<
          _$ConditionDatabase,
          $ConditionLogsTable,
          ConditionLog,
          $$ConditionLogsTableFilterComposer,
          $$ConditionLogsTableOrderingComposer,
          $$ConditionLogsTableAnnotationComposer,
          $$ConditionLogsTableCreateCompanionBuilder,
          $$ConditionLogsTableUpdateCompanionBuilder,
          (
            ConditionLog,
            BaseReferences<
              _$ConditionDatabase,
              $ConditionLogsTable,
              ConditionLog
            >,
          ),
          ConditionLog,
          PrefetchHooks Function()
        > {
  $$ConditionLogsTableTableManager(
    _$ConditionDatabase db,
    $ConditionLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConditionLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConditionLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConditionLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> loggedOn = const Value.absent(),
                Value<int> severity = const Value.absent(),
                Value<double?> sleepHours = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ConditionLogsCompanion(
                id: id,
                loggedOn: loggedOn,
                severity: severity,
                sleepHours: sleepHours,
                memo: memo,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime loggedOn,
                required int severity,
                Value<double?> sleepHours = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                required DateTime createdAt,
              }) => ConditionLogsCompanion.insert(
                id: id,
                loggedOn: loggedOn,
                severity: severity,
                sleepHours: sleepHours,
                memo: memo,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConditionLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$ConditionDatabase,
      $ConditionLogsTable,
      ConditionLog,
      $$ConditionLogsTableFilterComposer,
      $$ConditionLogsTableOrderingComposer,
      $$ConditionLogsTableAnnotationComposer,
      $$ConditionLogsTableCreateCompanionBuilder,
      $$ConditionLogsTableUpdateCompanionBuilder,
      (
        ConditionLog,
        BaseReferences<_$ConditionDatabase, $ConditionLogsTable, ConditionLog>,
      ),
      ConditionLog,
      PrefetchHooks Function()
    >;

class $ConditionDatabaseManager {
  final _$ConditionDatabase _db;
  $ConditionDatabaseManager(this._db);
  $$ConditionLogsTableTableManager get conditionLogs =>
      $$ConditionLogsTableTableManager(_db, _db.conditionLogs);
}
