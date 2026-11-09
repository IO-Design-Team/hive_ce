// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TestModelsTable extends TestModels
    with TableInfo<$TestModelsTable, TestModel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _testModelFieldZeroMeta =
      const VerificationMeta('testModelFieldZero');
  @override
  late final GeneratedColumn<int> testModelFieldZero = GeneratedColumn<int>(
    'test_model_field_zero',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldOneMeta = const VerificationMeta(
    'testModelFieldOne',
  );
  @override
  late final GeneratedColumn<int> testModelFieldOne = GeneratedColumn<int>(
    'test_model_field_one',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldTwoMeta = const VerificationMeta(
    'testModelFieldTwo',
  );
  @override
  late final GeneratedColumn<int> testModelFieldTwo = GeneratedColumn<int>(
    'test_model_field_two',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldThreeMeta =
      const VerificationMeta('testModelFieldThree');
  @override
  late final GeneratedColumn<int> testModelFieldThree = GeneratedColumn<int>(
    'test_model_field_three',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldFourMeta =
      const VerificationMeta('testModelFieldFour');
  @override
  late final GeneratedColumn<int> testModelFieldFour = GeneratedColumn<int>(
    'test_model_field_four',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldFiveMeta =
      const VerificationMeta('testModelFieldFive');
  @override
  late final GeneratedColumn<int> testModelFieldFive = GeneratedColumn<int>(
    'test_model_field_five',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldSixMeta = const VerificationMeta(
    'testModelFieldSix',
  );
  @override
  late final GeneratedColumn<int> testModelFieldSix = GeneratedColumn<int>(
    'test_model_field_six',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldSevenMeta =
      const VerificationMeta('testModelFieldSeven');
  @override
  late final GeneratedColumn<int> testModelFieldSeven = GeneratedColumn<int>(
    'test_model_field_seven',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldEightMeta =
      const VerificationMeta('testModelFieldEight');
  @override
  late final GeneratedColumn<int> testModelFieldEight = GeneratedColumn<int>(
    'test_model_field_eight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testModelFieldNineMeta =
      const VerificationMeta('testModelFieldNine');
  @override
  late final GeneratedColumn<int> testModelFieldNine = GeneratedColumn<int>(
    'test_model_field_nine',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    testModelFieldZero,
    testModelFieldOne,
    testModelFieldTwo,
    testModelFieldThree,
    testModelFieldFour,
    testModelFieldFive,
    testModelFieldSix,
    testModelFieldSeven,
    testModelFieldEight,
    testModelFieldNine,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_models';
  @override
  VerificationContext validateIntegrity(
    Insertable<TestModel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('test_model_field_zero')) {
      context.handle(
        _testModelFieldZeroMeta,
        testModelFieldZero.isAcceptableOrUnknown(
          data['test_model_field_zero']!,
          _testModelFieldZeroMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldZeroMeta);
    }
    if (data.containsKey('test_model_field_one')) {
      context.handle(
        _testModelFieldOneMeta,
        testModelFieldOne.isAcceptableOrUnknown(
          data['test_model_field_one']!,
          _testModelFieldOneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldOneMeta);
    }
    if (data.containsKey('test_model_field_two')) {
      context.handle(
        _testModelFieldTwoMeta,
        testModelFieldTwo.isAcceptableOrUnknown(
          data['test_model_field_two']!,
          _testModelFieldTwoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldTwoMeta);
    }
    if (data.containsKey('test_model_field_three')) {
      context.handle(
        _testModelFieldThreeMeta,
        testModelFieldThree.isAcceptableOrUnknown(
          data['test_model_field_three']!,
          _testModelFieldThreeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldThreeMeta);
    }
    if (data.containsKey('test_model_field_four')) {
      context.handle(
        _testModelFieldFourMeta,
        testModelFieldFour.isAcceptableOrUnknown(
          data['test_model_field_four']!,
          _testModelFieldFourMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldFourMeta);
    }
    if (data.containsKey('test_model_field_five')) {
      context.handle(
        _testModelFieldFiveMeta,
        testModelFieldFive.isAcceptableOrUnknown(
          data['test_model_field_five']!,
          _testModelFieldFiveMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldFiveMeta);
    }
    if (data.containsKey('test_model_field_six')) {
      context.handle(
        _testModelFieldSixMeta,
        testModelFieldSix.isAcceptableOrUnknown(
          data['test_model_field_six']!,
          _testModelFieldSixMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldSixMeta);
    }
    if (data.containsKey('test_model_field_seven')) {
      context.handle(
        _testModelFieldSevenMeta,
        testModelFieldSeven.isAcceptableOrUnknown(
          data['test_model_field_seven']!,
          _testModelFieldSevenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldSevenMeta);
    }
    if (data.containsKey('test_model_field_eight')) {
      context.handle(
        _testModelFieldEightMeta,
        testModelFieldEight.isAcceptableOrUnknown(
          data['test_model_field_eight']!,
          _testModelFieldEightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldEightMeta);
    }
    if (data.containsKey('test_model_field_nine')) {
      context.handle(
        _testModelFieldNineMeta,
        testModelFieldNine.isAcceptableOrUnknown(
          data['test_model_field_nine']!,
          _testModelFieldNineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_testModelFieldNineMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TestModel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestModel(
      testModelFieldZero: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_zero'],
      )!,
      testModelFieldOne: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_one'],
      )!,
      testModelFieldTwo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_two'],
      )!,
      testModelFieldThree: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_three'],
      )!,
      testModelFieldFour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_four'],
      )!,
      testModelFieldFive: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_five'],
      )!,
      testModelFieldSix: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_six'],
      )!,
      testModelFieldSeven: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_seven'],
      )!,
      testModelFieldEight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_eight'],
      )!,
      testModelFieldNine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}test_model_field_nine'],
      )!,
    );
  }

  @override
  $TestModelsTable createAlias(String alias) {
    return $TestModelsTable(attachedDatabase, alias);
  }
}

class TestModelsCompanion extends UpdateCompanion<TestModel> {
  final Value<int> testModelFieldZero;
  final Value<int> testModelFieldOne;
  final Value<int> testModelFieldTwo;
  final Value<int> testModelFieldThree;
  final Value<int> testModelFieldFour;
  final Value<int> testModelFieldFive;
  final Value<int> testModelFieldSix;
  final Value<int> testModelFieldSeven;
  final Value<int> testModelFieldEight;
  final Value<int> testModelFieldNine;
  final Value<int> rowid;
  const TestModelsCompanion({
    this.testModelFieldZero = const Value.absent(),
    this.testModelFieldOne = const Value.absent(),
    this.testModelFieldTwo = const Value.absent(),
    this.testModelFieldThree = const Value.absent(),
    this.testModelFieldFour = const Value.absent(),
    this.testModelFieldFive = const Value.absent(),
    this.testModelFieldSix = const Value.absent(),
    this.testModelFieldSeven = const Value.absent(),
    this.testModelFieldEight = const Value.absent(),
    this.testModelFieldNine = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestModelsCompanion.insert({
    required int testModelFieldZero,
    required int testModelFieldOne,
    required int testModelFieldTwo,
    required int testModelFieldThree,
    required int testModelFieldFour,
    required int testModelFieldFive,
    required int testModelFieldSix,
    required int testModelFieldSeven,
    required int testModelFieldEight,
    required int testModelFieldNine,
    this.rowid = const Value.absent(),
  }) : testModelFieldZero = Value(testModelFieldZero),
       testModelFieldOne = Value(testModelFieldOne),
       testModelFieldTwo = Value(testModelFieldTwo),
       testModelFieldThree = Value(testModelFieldThree),
       testModelFieldFour = Value(testModelFieldFour),
       testModelFieldFive = Value(testModelFieldFive),
       testModelFieldSix = Value(testModelFieldSix),
       testModelFieldSeven = Value(testModelFieldSeven),
       testModelFieldEight = Value(testModelFieldEight),
       testModelFieldNine = Value(testModelFieldNine);
  static Insertable<TestModel> custom({
    Expression<int>? testModelFieldZero,
    Expression<int>? testModelFieldOne,
    Expression<int>? testModelFieldTwo,
    Expression<int>? testModelFieldThree,
    Expression<int>? testModelFieldFour,
    Expression<int>? testModelFieldFive,
    Expression<int>? testModelFieldSix,
    Expression<int>? testModelFieldSeven,
    Expression<int>? testModelFieldEight,
    Expression<int>? testModelFieldNine,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (testModelFieldZero != null)
        'test_model_field_zero': testModelFieldZero,
      if (testModelFieldOne != null) 'test_model_field_one': testModelFieldOne,
      if (testModelFieldTwo != null) 'test_model_field_two': testModelFieldTwo,
      if (testModelFieldThree != null)
        'test_model_field_three': testModelFieldThree,
      if (testModelFieldFour != null)
        'test_model_field_four': testModelFieldFour,
      if (testModelFieldFive != null)
        'test_model_field_five': testModelFieldFive,
      if (testModelFieldSix != null) 'test_model_field_six': testModelFieldSix,
      if (testModelFieldSeven != null)
        'test_model_field_seven': testModelFieldSeven,
      if (testModelFieldEight != null)
        'test_model_field_eight': testModelFieldEight,
      if (testModelFieldNine != null)
        'test_model_field_nine': testModelFieldNine,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestModelsCompanion copyWith({
    Value<int>? testModelFieldZero,
    Value<int>? testModelFieldOne,
    Value<int>? testModelFieldTwo,
    Value<int>? testModelFieldThree,
    Value<int>? testModelFieldFour,
    Value<int>? testModelFieldFive,
    Value<int>? testModelFieldSix,
    Value<int>? testModelFieldSeven,
    Value<int>? testModelFieldEight,
    Value<int>? testModelFieldNine,
    Value<int>? rowid,
  }) {
    return TestModelsCompanion(
      testModelFieldZero: testModelFieldZero ?? this.testModelFieldZero,
      testModelFieldOne: testModelFieldOne ?? this.testModelFieldOne,
      testModelFieldTwo: testModelFieldTwo ?? this.testModelFieldTwo,
      testModelFieldThree: testModelFieldThree ?? this.testModelFieldThree,
      testModelFieldFour: testModelFieldFour ?? this.testModelFieldFour,
      testModelFieldFive: testModelFieldFive ?? this.testModelFieldFive,
      testModelFieldSix: testModelFieldSix ?? this.testModelFieldSix,
      testModelFieldSeven: testModelFieldSeven ?? this.testModelFieldSeven,
      testModelFieldEight: testModelFieldEight ?? this.testModelFieldEight,
      testModelFieldNine: testModelFieldNine ?? this.testModelFieldNine,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (testModelFieldZero.present) {
      map['test_model_field_zero'] = Variable<int>(testModelFieldZero.value);
    }
    if (testModelFieldOne.present) {
      map['test_model_field_one'] = Variable<int>(testModelFieldOne.value);
    }
    if (testModelFieldTwo.present) {
      map['test_model_field_two'] = Variable<int>(testModelFieldTwo.value);
    }
    if (testModelFieldThree.present) {
      map['test_model_field_three'] = Variable<int>(testModelFieldThree.value);
    }
    if (testModelFieldFour.present) {
      map['test_model_field_four'] = Variable<int>(testModelFieldFour.value);
    }
    if (testModelFieldFive.present) {
      map['test_model_field_five'] = Variable<int>(testModelFieldFive.value);
    }
    if (testModelFieldSix.present) {
      map['test_model_field_six'] = Variable<int>(testModelFieldSix.value);
    }
    if (testModelFieldSeven.present) {
      map['test_model_field_seven'] = Variable<int>(testModelFieldSeven.value);
    }
    if (testModelFieldEight.present) {
      map['test_model_field_eight'] = Variable<int>(testModelFieldEight.value);
    }
    if (testModelFieldNine.present) {
      map['test_model_field_nine'] = Variable<int>(testModelFieldNine.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestModelsCompanion(')
          ..write('testModelFieldZero: $testModelFieldZero, ')
          ..write('testModelFieldOne: $testModelFieldOne, ')
          ..write('testModelFieldTwo: $testModelFieldTwo, ')
          ..write('testModelFieldThree: $testModelFieldThree, ')
          ..write('testModelFieldFour: $testModelFieldFour, ')
          ..write('testModelFieldFive: $testModelFieldFive, ')
          ..write('testModelFieldSix: $testModelFieldSix, ')
          ..write('testModelFieldSeven: $testModelFieldSeven, ')
          ..write('testModelFieldEight: $testModelFieldEight, ')
          ..write('testModelFieldNine: $testModelFieldNine, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class _$TestModelInsertable implements Insertable<TestModel> {
  TestModel _object;
  _$TestModelInsertable(this._object);
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    return TestModelsCompanion(
      testModelFieldZero: Value(_object.testModelFieldZero),
      testModelFieldOne: Value(_object.testModelFieldOne),
      testModelFieldTwo: Value(_object.testModelFieldTwo),
      testModelFieldThree: Value(_object.testModelFieldThree),
      testModelFieldFour: Value(_object.testModelFieldFour),
      testModelFieldFive: Value(_object.testModelFieldFive),
      testModelFieldSix: Value(_object.testModelFieldSix),
      testModelFieldSeven: Value(_object.testModelFieldSeven),
      testModelFieldEight: Value(_object.testModelFieldEight),
      testModelFieldNine: Value(_object.testModelFieldNine),
    ).toColumns(false);
  }
}

extension TestModelToInsertable on TestModel {
  _$TestModelInsertable toInsertable() {
    return _$TestModelInsertable(this);
  }
}

abstract class _$TestDatabase extends GeneratedDatabase {
  _$TestDatabase(QueryExecutor e) : super(e);
  $TestDatabaseManager get managers => $TestDatabaseManager(this);
  late final $TestModelsTable testModels = $TestModelsTable(this);
  late final Index testModelFieldZero = Index(
    'test_model_field_zero',
    'CREATE INDEX test_model_field_zero ON test_models (test_model_field_zero)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    testModels,
    testModelFieldZero,
  ];
}

typedef $$TestModelsTableCreateCompanionBuilder =
    TestModelsCompanion Function({
      required int testModelFieldZero,
      required int testModelFieldOne,
      required int testModelFieldTwo,
      required int testModelFieldThree,
      required int testModelFieldFour,
      required int testModelFieldFive,
      required int testModelFieldSix,
      required int testModelFieldSeven,
      required int testModelFieldEight,
      required int testModelFieldNine,
      Value<int> rowid,
    });
typedef $$TestModelsTableUpdateCompanionBuilder =
    TestModelsCompanion Function({
      Value<int> testModelFieldZero,
      Value<int> testModelFieldOne,
      Value<int> testModelFieldTwo,
      Value<int> testModelFieldThree,
      Value<int> testModelFieldFour,
      Value<int> testModelFieldFive,
      Value<int> testModelFieldSix,
      Value<int> testModelFieldSeven,
      Value<int> testModelFieldEight,
      Value<int> testModelFieldNine,
      Value<int> rowid,
    });

class $$TestModelsTableFilterComposer
    extends Composer<_$TestDatabase, $TestModelsTable> {
  $$TestModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get testModelFieldZero => $composableBuilder(
    column: $table.testModelFieldZero,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldOne => $composableBuilder(
    column: $table.testModelFieldOne,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldTwo => $composableBuilder(
    column: $table.testModelFieldTwo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldThree => $composableBuilder(
    column: $table.testModelFieldThree,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldFour => $composableBuilder(
    column: $table.testModelFieldFour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldFive => $composableBuilder(
    column: $table.testModelFieldFive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldSix => $composableBuilder(
    column: $table.testModelFieldSix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldSeven => $composableBuilder(
    column: $table.testModelFieldSeven,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldEight => $composableBuilder(
    column: $table.testModelFieldEight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get testModelFieldNine => $composableBuilder(
    column: $table.testModelFieldNine,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TestModelsTableOrderingComposer
    extends Composer<_$TestDatabase, $TestModelsTable> {
  $$TestModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get testModelFieldZero => $composableBuilder(
    column: $table.testModelFieldZero,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldOne => $composableBuilder(
    column: $table.testModelFieldOne,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldTwo => $composableBuilder(
    column: $table.testModelFieldTwo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldThree => $composableBuilder(
    column: $table.testModelFieldThree,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldFour => $composableBuilder(
    column: $table.testModelFieldFour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldFive => $composableBuilder(
    column: $table.testModelFieldFive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldSix => $composableBuilder(
    column: $table.testModelFieldSix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldSeven => $composableBuilder(
    column: $table.testModelFieldSeven,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldEight => $composableBuilder(
    column: $table.testModelFieldEight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get testModelFieldNine => $composableBuilder(
    column: $table.testModelFieldNine,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TestModelsTableAnnotationComposer
    extends Composer<_$TestDatabase, $TestModelsTable> {
  $$TestModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get testModelFieldZero => $composableBuilder(
    column: $table.testModelFieldZero,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldOne => $composableBuilder(
    column: $table.testModelFieldOne,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldTwo => $composableBuilder(
    column: $table.testModelFieldTwo,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldThree => $composableBuilder(
    column: $table.testModelFieldThree,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldFour => $composableBuilder(
    column: $table.testModelFieldFour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldFive => $composableBuilder(
    column: $table.testModelFieldFive,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldSix => $composableBuilder(
    column: $table.testModelFieldSix,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldSeven => $composableBuilder(
    column: $table.testModelFieldSeven,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldEight => $composableBuilder(
    column: $table.testModelFieldEight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get testModelFieldNine => $composableBuilder(
    column: $table.testModelFieldNine,
    builder: (column) => column,
  );
}

class $$TestModelsTableTableManager
    extends
        RootTableManager<
          _$TestDatabase,
          $TestModelsTable,
          TestModel,
          $$TestModelsTableFilterComposer,
          $$TestModelsTableOrderingComposer,
          $$TestModelsTableAnnotationComposer,
          $$TestModelsTableCreateCompanionBuilder,
          $$TestModelsTableUpdateCompanionBuilder,
          (
            TestModel,
            BaseReferences<_$TestDatabase, $TestModelsTable, TestModel>,
          ),
          TestModel,
          PrefetchHooks Function()
        > {
  $$TestModelsTableTableManager(_$TestDatabase db, $TestModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> testModelFieldZero = const Value.absent(),
                Value<int> testModelFieldOne = const Value.absent(),
                Value<int> testModelFieldTwo = const Value.absent(),
                Value<int> testModelFieldThree = const Value.absent(),
                Value<int> testModelFieldFour = const Value.absent(),
                Value<int> testModelFieldFive = const Value.absent(),
                Value<int> testModelFieldSix = const Value.absent(),
                Value<int> testModelFieldSeven = const Value.absent(),
                Value<int> testModelFieldEight = const Value.absent(),
                Value<int> testModelFieldNine = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TestModelsCompanion(
                testModelFieldZero: testModelFieldZero,
                testModelFieldOne: testModelFieldOne,
                testModelFieldTwo: testModelFieldTwo,
                testModelFieldThree: testModelFieldThree,
                testModelFieldFour: testModelFieldFour,
                testModelFieldFive: testModelFieldFive,
                testModelFieldSix: testModelFieldSix,
                testModelFieldSeven: testModelFieldSeven,
                testModelFieldEight: testModelFieldEight,
                testModelFieldNine: testModelFieldNine,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int testModelFieldZero,
                required int testModelFieldOne,
                required int testModelFieldTwo,
                required int testModelFieldThree,
                required int testModelFieldFour,
                required int testModelFieldFive,
                required int testModelFieldSix,
                required int testModelFieldSeven,
                required int testModelFieldEight,
                required int testModelFieldNine,
                Value<int> rowid = const Value.absent(),
              }) => TestModelsCompanion.insert(
                testModelFieldZero: testModelFieldZero,
                testModelFieldOne: testModelFieldOne,
                testModelFieldTwo: testModelFieldTwo,
                testModelFieldThree: testModelFieldThree,
                testModelFieldFour: testModelFieldFour,
                testModelFieldFive: testModelFieldFive,
                testModelFieldSix: testModelFieldSix,
                testModelFieldSeven: testModelFieldSeven,
                testModelFieldEight: testModelFieldEight,
                testModelFieldNine: testModelFieldNine,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TestModelsTable, TestModel>(table),
                  BaseReferences<_$TestDatabase, $TestModelsTable, TestModel>(
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

typedef $$TestModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$TestDatabase,
      $TestModelsTable,
      TestModel,
      $$TestModelsTableFilterComposer,
      $$TestModelsTableOrderingComposer,
      $$TestModelsTableAnnotationComposer,
      $$TestModelsTableCreateCompanionBuilder,
      $$TestModelsTableUpdateCompanionBuilder,
      (TestModel, BaseReferences<_$TestDatabase, $TestModelsTable, TestModel>),
      TestModel,
      PrefetchHooks Function()
    >;

class $TestDatabaseManager {
  final _$TestDatabase _db;
  $TestDatabaseManager(this._db);
  $$TestModelsTableTableManager get testModels =>
      $$TestModelsTableTableManager(_db, _db.testModels);
}
