import 'package:hive/hive.dart';
import 'package:isar/isar.dart';
import 'package:storage_benchmark/bench_target.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/db_type.dart';
import 'package:storage_benchmark/test_model.dart';

void main() async {
  await Isar.initialize('assets/libisar_macos.dylib');

  Hive.defaultDirectory = '.';
  Hive.registerAdapter('TestModel', (json) => TestModel.fromJson(json));

  // add and addAll commit to disk before they return.
  final hive = BenchTarget(
    name: 'Hive v4',
    type: DbType.isar,
    openBox: (name) => Hive.box(name: name, maxSizeMiB: 1024),
    readAll: (box) => box.getRange(0, box.length),
  );

  await runBenchmarks(
    writeTargets: [hive],
    batchTargets: [hive],
    openTargets: [hive],
  );

  Hive.closeAllBoxes();
}
