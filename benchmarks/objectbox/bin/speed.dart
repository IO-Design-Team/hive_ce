import 'package:objectbox_storage_benchmark/objectbox.g.dart';
import 'package:objectbox_storage_benchmark/test_entity.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() async {
  await runSpeedBenchmarks([
    SpeedTarget(
      name: 'ObjectBox',
      path: 'memory_box',
      open: () => openStore(directory: 'memory_box'),
      writeAll: (store, values) {
        (store as Store).box<TestEntity>().putMany([
          for (final value in values) TestEntity.fromModel(value),
        ]);
      },
      close: (store) => (store as Store).close(),
      readAll: (store) => (store as Store).box<TestEntity>().getAll(),
    ),
  ]);
}
