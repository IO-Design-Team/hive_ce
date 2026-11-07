import 'package:drift/drift.dart';
import 'package:storage_benchmark/test_model.dart';

part 'database.g.dart';

@UseRowClass(TestModel, generateInsertable: true)
class TestModels extends Table {
  IntColumn get testModelFieldZero => integer()();
  IntColumn get testModelFieldOne => integer()();
  IntColumn get testModelFieldTwo => integer()();
  IntColumn get testModelFieldThree => integer()();
  IntColumn get testModelFieldFour => integer()();
  IntColumn get testModelFieldFive => integer()();
  IntColumn get testModelFieldSix => integer()();
  IntColumn get testModelFieldSeven => integer()();
  IntColumn get testModelFieldEight => integer()();
  IntColumn get testModelFieldNine => integer()();
}

@DriftDatabase(tables: [TestModels])
class TestDatabase extends _$TestDatabase {
  TestDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
