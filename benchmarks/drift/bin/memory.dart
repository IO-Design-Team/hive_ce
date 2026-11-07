import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_storage_benchmark/database.dart';
import 'package:storage_benchmark/memory_benchmark.dart';

void main(List<String> args) async {
  TestDatabase openDatabase() =>
      TestDatabase(NativeDatabase.createInBackground(File('memory_box.db')));

  await runMemoryBenchmarks(args, [
    MemoryTarget(
      name: 'drift',
      path: 'memory_box.db',
      write: (values) async {
        final db = openDatabase();
        await db.batch(
          (batch) => batch.insertAll(db.testModels, [
            for (final value in values) value.toInsertable(),
          ]),
        );
        await db.close();
      },
      open: () async {
        final db = openDatabase();
        await db.executor.ensureOpen(db);
        return db;
      },
      readAll: (db) => (db as TestDatabase).select(db.testModels).get(),
    ),
  ]);
}
