import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_storage_benchmark/database.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() async {
  Future<TestDatabase> open() async {
    final db = TestDatabase(
      NativeDatabase.createInBackground(File('memory_box.db')),
    );
    await db.executor.ensureOpen(db);
    return db;
  }

  await runSpeedBenchmarks([
    SpeedTarget(
      name: 'drift',
      path: 'memory_box.db',
      open: open,
      writeAll: (db, values) => (db as TestDatabase).batch(
        (batch) => batch.insertAll(db.testModels, [
          for (final value in values) value.toInsertable(),
        ]),
      ),
      close: (db) => (db as TestDatabase).close(),
      readAll: (db) => (db as TestDatabase).select(db.testModels).get(),
    ),
  ]);
}
