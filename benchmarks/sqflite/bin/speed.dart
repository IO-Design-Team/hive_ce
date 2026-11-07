import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/speed_benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

const _table = 'test_models';

void main() async {
  final path = File('memory_box.db').absolute.path;
  final columns = testModel
      .toJson()
      .keys
      .map((column) => '$column INTEGER NOT NULL')
      .join(', ');

  Future<Database> open() => databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA synchronous = FULL');
      },
      onCreate: (db, _) =>
          db.execute('CREATE TABLE $_table (id INTEGER PRIMARY KEY, $columns)'),
    ),
  );

  await runSpeedBenchmarks([
    SpeedTarget(
      name: 'sqflite',
      path: path,
      open: open,
      writeAll: (db, values) async {
        final batch = (db as Database).batch();
        for (final value in values) {
          batch.insert(_table, value.toJson());
        }
        await batch.commit(noResult: true);
      },
      close: (db) => (db as Database).close(),
      readAll: (db) async {
        final rows = await (db as Database).query(_table);
        return rows.map(TestModel.fromJson).toList();
      },
    ),
  ]);
}
