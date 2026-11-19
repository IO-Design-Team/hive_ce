import 'dart:io';

import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/report.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

/// Times durable writes, reopening for a read, and queries on an open database.
Future<List<BenchmarkResult>> runSpeedBenchmarks(List<Target> targets) async {
  final results = <BenchmarkResult>[];
  final scenarios = Scenario.values.where(
    (scenario) => scenario.workload == Workload.standard,
  );
  final values = testModels(recordCount);

  for (final target in targets) {
    await target.initialize?.call();
    try {
      var batchTimedOut = false;
      for (final scenario in scenarios) {
        stdout.write('${target.name} · ${scenario.label} … ');
        final time = batchTimedOut
            ? null
            : await _averageTime(target, scenario, values);
        if (scenario == Scenario.batchWrite && time == null) {
          batchTimedOut = true;
        }
        final result = BenchmarkResult(scenario, target.name, value: time);
        results.add(result);
        stdout.writeln(
          time == null ? result.displayValue : '${result.displayValue} ms',
        );
      }
    } finally {
      await target.close?.call();
    }
  }
  return results;
}

Future<int?> _averageTime(
  Target target,
  Scenario scenario,
  List<TestModel> values,
) async {
  try {
    return averageSamples(
      await collectSamples(() => _measure(target, scenario, values)),
    );
  } on TimeLimitExceeded {
    return null;
  }
}

/// Both writes start with an empty database and include the final flush.
/// The batch write leaves the database used for the open and query timings.
Future<int> _measure(Target target, Scenario scenario, List<TestModel> values) {
  final stopwatch = Stopwatch();
  if (scenario == Scenario.individualWrite || scenario == Scenario.batchWrite) {
    deleteDatabase(target.path);
  }
  if (scenario == Scenario.openAndRead) stopwatch.start();

  return withDatabase(target.open, (db) async {
    stopwatch.start();
    switch (scenario) {
      case Scenario.individualWrite:
        for (final value in values) {
          if (stopwatch.elapsed >= timeLimit) throw TimeLimitExceeded();
          await db.add(value);
        }
        await db.flush();
      case Scenario.batchWrite:
        await db.writeBatch(values);
      case Scenario.openAndRead:
        checkCount(await db.readAfterOpen(), recordCount);
      case Scenario.query:
        const min = recordCount ~/ 2;
        const max = min + recordCount ~/ 10;
        checkCount(await db.query(min, max), max - min);
      default:
        throw ArgumentError.value(scenario, 'scenario');
    }
    stopwatch.stop();
    if (stopwatch.elapsed >= timeLimit) throw TimeLimitExceeded();
    return stopwatch.elapsedMicroseconds;
  });
}
