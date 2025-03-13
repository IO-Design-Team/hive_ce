import 'dart:io';

import 'package:csv/csv.dart';
import 'package:hive/hive.dart' as v4;
import 'package:hive_ce/hive.dart' as ce;
import 'package:hive_storage_benchmark/bench_result.dart';
import 'package:hive_storage_benchmark/benchmark.dart';
import 'package:hive_storage_benchmark/db_type.dart';
import 'package:hive_storage_benchmark/test_model.dart';
import 'package:isar/isar.dart';

const benchmarks = [
  10,
  100,
  1000,
  10000,
  100000,
  1000000,
];

void main() async {
  ce.Hive
    ..init('.')
    ..registerAdapter(TestModelAdapter());

  await ce.IsolatedHive.init('.');
  await ce.IsolatedHive.registerAdapter(TestModelAdapter());

  await Isar.initialize('assets/libisar_macos.dylib');

  v4.Hive.defaultDirectory = '.';
  v4.Hive.registerAdapter('TestModel', (json) => TestModel.fromJson(json));

  final ceResults = <BenchResult>[];
  final isolatedResults = <BenchResult>[];
  final v4Results = <BenchResult>[];

  for (final operations in benchmarks) {
    final ceResult = await runBenchmark(
      name: 'Hive CE',
      operations: operations,
      type: DbType.hive,
      openBox: ce.Hive.openBox,
    );

    final isolatedResult = await runBenchmark(
      name: 'IsolatedHive',
      operations: operations,
      type: DbType.hive,
      openBox: ce.IsolatedHive.openBox,
    );

    final v4Result = await runBenchmark(
      name: 'Hive v4',
      operations: operations,
      type: DbType.isar,
      openBox: (name) => v4.Hive.box(name: name, maxSizeMiB: 1024),
    );

    ceResults.add(ceResult);
    isolatedResults.add(isolatedResult);
    v4Results.add(v4Result);
  }

  await ce.Hive.close();
  await ce.IsolatedHive.close();
  v4.Hive.closeAllBoxes();

  final csv = const ListToCsvConverter().convert([
    [
      'Operations',
      'Hive CE Time',
      'IsolatedHive Time',
      'Hive CE Size',
      'Hive v4 Time',
      'Hive v4 Size',
    ],
    for (var i = 0; i < benchmarks.length; i++)
      [
        benchmarks[i],
        formatTime(ceResults[i].time),
        formatTime(isolatedResults[i].time),
        formatSize(ceResults[i].size),
        formatTime(v4Results[i].time),
        formatSize(v4Results[i].size),
      ],
  ]);

  File('results.csv').writeAsStringSync(csv);
}

// Format a duration to "00.00 s"
String formatTime(Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(2)} s';
}

String formatSize(double size) {
  return '${size.toStringAsFixed(2)} MB';
}
