import 'package:hive/hive.dart';
import 'package:isar/isar.dart';
import 'package:storage_benchmark/memory_benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

void main(List<String> args) async {
  await Isar.initialize('assets/libisar_macos.dylib');

  Hive.defaultDirectory = '.';
  Hive.registerAdapter('TestModel', (json) => TestModel.fromJson(json));

  Box<TestModel> openBox() => Hive.box(name: 'memory_box', maxSizeMiB: 1024);

  await runMemoryBenchmarks(args, [
    MemoryTarget(
      name: 'Hive v4',
      path: 'memory_box.isar',
      write: (values) {
        openBox()
          ..addAll(values)
          ..close();
      },
      open: openBox,
      readAll: (box) => box.getRange(0, box.length),
    ),
  ]);
}
