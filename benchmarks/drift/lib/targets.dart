import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_storage_benchmark/database.dart';
import 'package:storage_benchmark/target.dart';

final drift = Target.create(
  name: 'drift',
  path: 'test_box.db',
  open: () async {
    final db = TestDatabase(
      NativeDatabase.createInBackground(File('test_box.db')),
    );
    await db.executor.ensureOpen(db);
    return db;
  },
  add: (db, value) => db.into(db.testModels).insert(value.toInsertable()),
  addAll: (db, values) => db.batch(
    (batch) => batch.insertAll(db.testModels, [
      for (final value in values) value.toInsertable(),
    ]),
  ),
  readAll: (db) => db.select(db.testModels).get(),
  close: (db) => db.close(),
);
