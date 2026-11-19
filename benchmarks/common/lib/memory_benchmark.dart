import 'dart:io';

import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/report.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const workerEnvironment = 'HIVE_BENCH_WORKER';
const _resultPrefix = 'BENCH ';

/// Measures peak RSS and database size. Each sample starts a fresh process
/// because a process's peak RSS never decreases.
Future<List<BenchmarkResult>> runMemoryBenchmarks(List<Target> targets) async {
  final results = <BenchmarkResult>[];
  for (final (index, target) in targets.indexed) {
    stdout.write('${target.name} · Memory and size … ');
    final samples = await collectSamples(() => _measure(index, target));
    final write = averageSamples(samples.map((sample) => sample.write));
    final open = averageSamples(samples.map((sample) => sample.open));
    final read = averageSamples(samples.map((sample) => sample.read));
    final size = averageSamples(samples.map((sample) => sample.size));

    results.addAll([
      BenchmarkResult(Scenario.writePeak, target.name, value: write),
      BenchmarkResult(Scenario.openPeak, target.name, value: open),
      BenchmarkResult(Scenario.readPeak, target.name, value: read),
      BenchmarkResult(Scenario.databaseSize, target.name, value: size),
    ]);
    stdout.writeln(
      '${Scenario.writePeak.format(write)} MiB write, '
      '${Scenario.openPeak.format(open)} MiB open, '
      '${Scenario.readPeak.format(read)} MiB read, '
      '${Scenario.databaseSize.format(size)} MiB on disk',
    );
  }
  return results;
}

Future<({int write, int open, int read, int size})> _measure(
  int index,
  Target target,
) async {
  final [write] = await _runWorker('write $index');
  final size = databaseSize(target.path);
  final [open, read] = await _runWorker('open $index');
  return (write: write, open: open, read: read, size: size);
}

Future<void> runMemoryWorker(List<Target> targets, String spec) async {
  final [scenario, index] = spec.split(' ');
  final target = targets[int.parse(index)];
  final baseline = ProcessInfo.currentRss;
  await target.initialize?.call();

  try {
    switch (scenario) {
      case 'write':
        final values = testModels(recordCount);
        deleteDatabase(target.path);
        await withDatabase(target.open, (db) => db.writeBatch(values));
        stdout.writeln('$_resultPrefix${ProcessInfo.maxRss - baseline}');
      case 'open':
        final [open, read] = await withDatabase(target.open, (db) async {
          final open = ProcessInfo.maxRss - baseline;
          final values = await db.readAll();
          final read = ProcessInfo.maxRss - baseline;
          checkCount(values, recordCount);
          return [open, read];
        });
        stdout.writeln('$_resultPrefix$open $read');
      default:
        throw ArgumentError('Unknown memory benchmark: $scenario');
    }
  } finally {
    await target.close?.call();
  }
  await stdout.flush();
}

Future<List<int>> _runWorker(String spec) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    const [],
    environment: {workerEnvironment: spec},
  );
  final measurements = (result.stdout as String)
      .split('\n')
      .where((line) => line.startsWith(_resultPrefix));
  if (result.exitCode != 0 || measurements.isEmpty) {
    throw StateError(
      'Memory measurement $spec failed:\n${result.stdout}${result.stderr}',
    );
  }
  return measurements.last
      .substring(_resultPrefix.length)
      .split(' ')
      .map(int.parse)
      .toList();
}
