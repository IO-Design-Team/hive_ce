import 'package:hive/hive.dart';
import 'package:hive_v2_storage_benchmark/test_model_adapter.dart';
import 'package:storage_benchmark/memory_benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

void main(List<String> args) async {
  Hive
    ..init('.')
    ..registerAdapter(TestModelAdapter());

  await runMemoryBenchmarks(args, [
    MemoryTarget(
      name: 'Hive v2',
      path: 'memory_box.hive',
      write: (values) async {
        final box = await Hive.openBox<TestModel>('memory_box');
        await box.addAll(values);
        await box.close();
      },
      open: () => Hive.openBox<TestModel>('memory_box'),
      readAll: (box) => box.values.toList(),
    ),
  ]);
}
