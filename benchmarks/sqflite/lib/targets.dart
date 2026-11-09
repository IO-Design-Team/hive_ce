import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _table = 'test_models';
final _path = File('test_box.db').absolute.path;

final sqflite = Target.create(
  name: 'sqflite',
  path: _path,
  open: () => databaseFactoryFfi.openDatabase(
    _path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        final columns = [
          for (final column in testModel.toJson().keys)
            '$column INTEGER NOT NULL',
        ];
        await db.execute(
          'CREATE TABLE $_table (id INTEGER PRIMARY KEY, ${columns.join(', ')})',
        );
        await db.execute(
          'CREATE INDEX test_model_field_zero ON $_table (testModelFieldZero)',
        );
      },
    ),
  ),
  add: (db, value) => db.insert(_table, value.toJson()),
  addAll: (db, values) async {
    final batch = db.batch();
    for (final value in values) {
      batch.insert(_table, value.toJson());
    }
    await batch.commit(noResult: true);
  },
  readAll: (db) async =>
      (await db.query(_table)).map(TestModel.fromJson).toList(),
  query: (db, min, max) async => (await db.query(
    _table,
    where: 'testModelFieldZero >= ? AND testModelFieldZero < ?',
    whereArgs: [min, max],
  )).map(TestModel.fromJson).toList(),
  close: (db) => db.close(),
);
