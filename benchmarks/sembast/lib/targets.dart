import 'dart:io';

import 'package:sembast/sembast_io.dart';
// sembast has no public way to wait for pending writes
// ignore: implementation_imports
import 'package:sembast/src/database_impl.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _path = 'test_box.db';
final _store = intMapStoreFactory.store();

final sembast = Target.create(
  name: 'sembast',
  path: _path,
  open: () => databaseFactoryIo.openDatabase(_path),
  add: (db, value) => _store.add(db, value.toJson()),
  addAll: (db, values) =>
      _store.addAll(db, [for (final value in values) value.toJson()]),
  flush: (db) async {
    // Writes return before sembast appends the records to its file
    await (db as SembastDatabase).flush();
    final file = await File(_path).open(mode: FileMode.append);
    try {
      await file.flush();
    } finally {
      await file.close();
    }
  },
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
