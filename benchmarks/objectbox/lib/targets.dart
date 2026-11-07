import 'package:objectbox_storage_benchmark/objectbox.g.dart';
import 'package:objectbox_storage_benchmark/test_entity.dart';
import 'package:storage_benchmark/target.dart';

const _path = 'test_box';

/// `putMany` commits to disk before it returns, so there is no flush
final objectBox = Target.create(
  name: 'ObjectBox',
  path: _path,
  open: () => openStore(directory: _path),
  addAll: (store, values) => store.box<TestEntity>().putMany([
    for (final value in values) TestEntity.fromModel(value),
  ]),
  readAll: (store) => store.box<TestEntity>().getAll(),
  close: (store) => store.close(),
);
