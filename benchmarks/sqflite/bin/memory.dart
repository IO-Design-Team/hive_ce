import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/memory_benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

const _table = 'test_models';

void main(List<String> args) async {
  final path = File('memory_box.db').absolute.path;
  final columns = testModel
      .toJson()
      .keys
      .map((column) => '$column INTEGER NOT NULL')
      .join(', ');

  await runMemoryBenchmarks(args, [
    MemoryTarget(
      name: 'sqflite',
      path: path,
      write: (values) async {
        final db = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) => db.execute(
              'CREATE TABLE $_table (id INTEGER PRIMARY KEY, $columns)',
            ),
          ),
        );
        final batch = db.batch();
        for (final value in values) {
          batch.insert(_table, value.toJson());
        }
        await batch.commit(noResult: true);
        await db.close();
      },
      open: () => databaseFactoryFfi.openDatabase(path),
      readAll: (db) async =>
          (await db.query(_table) as List<Map<String, Object?>>)
              .map(TestModel.fromJson)
              .toList(),
    ),
  ]);
}
