import 'dart:async';
import 'dart:io';

import 'package:storage_benchmark/large_values.dart';
import 'package:storage_benchmark/memory_benchmark.dart';
import 'package:storage_benchmark/report.dart';
import 'package:storage_benchmark/speed_benchmark.dart';
import 'package:storage_benchmark/target.dart';

Future<void> runBenchmarks({
  required List<Target> targets,
  FutureOr<void> Function()? initialize,
}) async {
  try {
    await initialize?.call();
    await _run(targets);
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exit(1);
  }
}

Future<void> _run(List<Target> targets) async {
  final env = Platform.environment;
  final worker = env[workerEnvironment];
  if (worker != null) {
    await runMemoryWorker(targets, worker);
    return;
  }

  final results = [
    ...await runSpeedBenchmarks(targets),
    ...await runMemoryBenchmarks(targets),
    ...await runLargeValueBenchmarks(targets),
  ];
  final resultFile = env['HIVE_BENCH_RESULT_FILE'];
  if (resultFile == null) {
    writeReport(results);
  } else {
    writeResultFile(resultFile, results);
  }
}
