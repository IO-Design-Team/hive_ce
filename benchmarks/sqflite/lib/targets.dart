import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _table = 'test_models';
const _largeTable = 'large_values';
final _path = File('test_box.db').absolute.path;

final sqflite = Target.create(
  name: 'sqflite',
  path: _path,
  initialize: sqfliteFfiInit,
  openLarge: largeDatabase(
    open: (path) => databaseFactoryFfi.openDatabase(
      '$path/values.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) =>
            db.execute('CREATE TABLE $_largeTable (value BLOB NOT NULL)'),
      ),
    ),
    addAll: (db, values) =>
        _insertBatch(db, _largeTable, values.map((value) => {'value': value})),
    readAll: (db) async => [
      for (final row in await db.query(_largeTable)) row['value'] as Uint8List,
    ],
    close: (db) => db.close(),
  ),
  open: () => databaseFactoryFfi.openDatabase(
    _path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        const sample = TestModel.withIndex(0);
        final columns = [
          for (final column in sample.toJson().keys) '$column INTEGER NOT NULL',
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
  addAll: (db, values) =>
      _insertBatch(db, _table, values.map((value) => value.toJson())),
  readAll: (db) async =>
      (await db.query(_table)).map(TestModel.fromJson).toList(),
  query: (db, min, max) async => (await db.query(
    _table,
    where: 'testModelFieldZero >= ? AND testModelFieldZero < ?',
    whereArgs: [min, max],
  )).map(TestModel.fromJson).toList(),
  close: (db) => db.close(),
);

Future<void> _insertBatch(
  Database db,
  String table,
  Iterable<Map<String, Object?>> rows,
) async {
  final batch = db.batch();
  for (final row in rows) {
    batch.insert(table, row);
  }
  await batch.commit(noResult: true);
}
