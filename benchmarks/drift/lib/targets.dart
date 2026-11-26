import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_storage_benchmark/database.dart';
import 'package:storage_benchmark/target.dart';

const _path = 'test_box.db';
const _largeTable = 'large_values';

final drift = Target.create(
  name: 'drift',
  path: _path,
  openLarge: largeDatabase(
    open: (path) => _open('$path/values.db', _LargeValueDatabase.new),
    addAll: (db, values) => db.batch((batch) {
      for (final value in values) {
        batch.customStatement('INSERT INTO $_largeTable (value) VALUES (?)', [
          value,
        ]);
      }
    }),
    readAll: (db) async => [
      for (final row
          in await db.customSelect('SELECT value FROM $_largeTable').get())
        row.read<Uint8List>('value'),
    ],
    close: (db) => db.close(),
  ),
  open: () => _open(_path, TestDatabase.new),
  add: (db, value) => db.into(db.testModels).insert(value.toInsertable()),
  addAll: (db, values) => db.batch(
    (batch) => batch.insertAll(db.testModels, [
      for (final value in values) value.toInsertable(),
    ]),
  ),
  readAll: (db) => db.select(db.testModels).get(),
  query: (db, min, max) =>
      (db.select(db.testModels)..where(
            (row) =>
                row.testModelFieldZero.isBiggerOrEqualValue(min) &
                row.testModelFieldZero.isSmallerThanValue(max),
          ))
          .get(),
  close: (db) => db.close(),
);

Future<T> _open<T extends GeneratedDatabase>(
  String path,
  T Function(QueryExecutor executor) create,
) async {
  final db = create(NativeDatabase.createInBackground(File(path)));
  try {
    await db.executor.ensureOpen(db);
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}

class _LargeValueDatabase extends GeneratedDatabase {
  _LargeValueDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) =>
        customStatement('CREATE TABLE $_largeTable (value BLOB NOT NULL)'),
  );
}
