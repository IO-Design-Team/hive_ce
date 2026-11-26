import 'dart:io';

import 'package:sembast/blob.dart';
import 'package:sembast/sembast_io.dart';
// sembast has no public way to wait for pending writes
// ignore: implementation_imports
import 'package:sembast/src/database_impl.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _path = 'test_box.db';
final _store = intMapStoreFactory.store();
final _largeStore = StoreRef<int, Blob>('large_values');

final sembast = Target.create(
  name: 'sembast',
  path: _path,
  openLarge: largeDatabase(
    open: (path) => databaseFactoryIo.openDatabase('$path/values.db'),
    addAll: (db, values) =>
        _largeStore.addAll(db, values.map(Blob.new).toList()),
    flush: _flush,
    readAll: (db) async => [
      for (final record in await _largeStore.find(db)) record.value.bytes,
    ],
    close: (db) => db.close(),
  ),
  open: () => databaseFactoryIo.openDatabase(_path),
  add: (db, value) => _store.add(db, value.toJson()),
  addAll: (db, values) =>
      _store.addAll(db, [for (final value in values) value.toJson()]),
  flush: _flush,
  readAll: (db) async => [
    for (final record in await _store.find(db))
      TestModel.fromJson(record.value),
  ],
  query: (db, min, max) async => [
    for (final record in await _store.find(
      db,
      finder: Finder(
        filter: Filter.and([
          Filter.greaterThanOrEquals('testModelFieldZero', min),
          Filter.lessThan('testModelFieldZero', max),
        ]),
      ),
    ))
      TestModel.fromJson(record.value),
  ],
  close: (db) => db.close(),
);

Future<void> _flush(Database db) async {
  // Writes return before sembast appends the records to its file.
  await (db as SembastDatabase).flush();
  final file = await File(db.path).open(mode: FileMode.append);
  try {
    await file.flush();
  } finally {
    await file.close();
  }
}
