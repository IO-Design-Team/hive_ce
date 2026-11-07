import 'package:objectbox_storage_benchmark/objectbox.g.dart';
import 'package:objectbox_storage_benchmark/test_entity.dart';
import 'package:storage_benchmark/memory_benchmark.dart';

void main(List<String> args) async {
  await runMemoryBenchmarks(args, [
    MemoryTarget(
      name: 'ObjectBox',
      path: 'memory_box',
      write: (values) {
        final store = openStore(directory: 'memory_box');
        store.box<TestEntity>().putMany([
          for (final value in values) TestEntity.fromModel(value),
        ]);
        store.close();
      },
      open: () => openStore(directory: 'memory_box'),
      readAll: (store) => (store as Store).box<TestEntity>().getAll(),
    ),
  ]);
}
