import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_storage_benchmark/test_model_adapter.dart';
import 'package:storage_benchmark/memory_benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

void main(List<String> args) async {
  Hive
    ..init('.')
    ..registerAdapter(TestModelAdapter());

  await runMemoryBenchmarks(args, [
    MemoryTarget(
      name: 'Hive CE',
      path: 'memory_box.hive',
      write: (values) async {
        final box = await Hive.openBox<TestModel>('memory_box');
        await box.addAll(values);
        await box.close();
      },
      open: () => Hive.openBox<TestModel>('memory_box'),
      readAll: (box) => box.values.toList(),
    ),
    MemoryTarget(
      name: 'Hive CE (lazy)',
      path: 'memory_box.hive',
      write: (values) async {
        final box = await Hive.openLazyBox<TestModel>('memory_box');
        await box.addAll(values);
        await box.close();
      },
      open: () => Hive.openLazyBox<TestModel>('memory_box'),
      readAll: (box) async => [
        for (var i = 0; i < box.length; i++) await box.getAt(i),
      ],
    ),
  ]);
}
