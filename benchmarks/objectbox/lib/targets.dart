import 'package:objectbox_storage_benchmark/objectbox.g.dart';
import 'package:objectbox_storage_benchmark/test_entity.dart';
import 'package:storage_benchmark/target.dart';

const _path = 'test_box';

/// `put` and `putMany` commit to disk before they return, so there is no flush
final objectBox = Target.create(
  name: 'ObjectBox',
  path: _path,
  openLarge: largeDatabase(
    open: (path) => openStore(directory: path),
    addAll: (store, values) => store.box<LargeValueEntity>().putMany(
      values.map(LargeValueEntity.new).toList(),
    ),
    readAll: (store) => [
      for (final entity in store.box<LargeValueEntity>().getAll()) entity.value,
    ],
    close: (store) => store.close(),
  ),
  open: () => openStore(directory: _path),
  add: (store, value) =>
      store.box<TestEntity>().put(TestEntity.fromModel(value)),
  addAll: (store, values) => store.box<TestEntity>().putMany([
    for (final value in values) TestEntity.fromModel(value),
  ]),
  readAll: (store) => store.box<TestEntity>().getAll(),
  query: (store, min, max) {
    final query = store
        .box<TestEntity>()
        .query(
          TestEntity_.testModelFieldZero.greaterOrEqual(min) &
              TestEntity_.testModelFieldZero.lessThan(max),
        )
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  },
  close: (store) => store.close(),
);
