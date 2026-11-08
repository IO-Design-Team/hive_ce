import 'package:objectbox_storage_benchmark/objectbox.g.dart';
import 'package:objectbox_storage_benchmark/test_entity.dart';
import 'package:storage_benchmark/target.dart';

const _path = 'test_box';

/// `put` and `putMany` commit to disk before they return, so there is no flush
final objectBox = Target.create(
  name: 'ObjectBox',
  path: _path,
  open: () => openStore(directory: _path),
  add: (store, value) =>
      store.box<TestEntity>().put(TestEntity.fromModel(value)),
  addAll: (store, values) => store.box<TestEntity>().putMany([
    for (final value in values) TestEntity.fromModel(value),
  ]),
  readAll: (store) => store.box<TestEntity>().getAll(),
  close: (store) => store.close(),
);
