import 'dart:io';
import 'dart:typed_data';

import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/report.dart';
import 'package:storage_benchmark/target.dart';

Future<List<BenchmarkResult>> runLargeValueBenchmarks(
  List<Target> targets,
) async {
  final values = [
    for (var index = 0; index < largeValueCount; index++)
      Uint8List(largeValueBytes)..fillRange(0, largeValueBytes, index),
  ];
  final results = <BenchmarkResult>[];
  for (final target in targets) {
    stdout.write('${target.name} · 1 MiB values … ');
    await target.initialize?.call();
    try {
      final samples = await collectSamples(
        () => _measure(target.openLarge, values),
      );
      final write = averageSamples(samples.map((sample) => sample.write));
      final reopen = averageSamples(samples.map((sample) => sample.reopen));
      results.addAll([
        BenchmarkResult(Scenario.largeValueWrite, target.name, value: write),
        BenchmarkResult(Scenario.largeValueOpen, target.name, value: reopen),
      ]);
      stdout.writeln(
        '${Scenario.largeValueWrite.format(write)} ms write, '
        '${Scenario.largeValueOpen.format(reopen)} ms reopen',
      );
    } finally {
      await target.close?.call();
    }
  }
  return results;
}

Future<({int write, int reopen})> _measure(
  OpenLargeDatabase open,
  List<Uint8List> values,
) async {
  final directory = await Directory.current.createTemp('large_values_');
  try {
    Future<BenchmarkDatabase<Uint8List, Uint8List>> openFixture() =>
        open(directory.path);
    final write = await withDatabase(openFixture, (db) async {
      final stopwatch = Stopwatch()..start();
      await db.writeBatch(values);
      return stopwatch.elapsedMicroseconds;
    });

    final reopen = Stopwatch()..start();
    final reopenTime = await withDatabase(openFixture, (db) async {
      reopen.stop();
      final stored = await db.readAll();
      checkCount(stored, values.length);
      final ids = <int>{};
      for (final value in stored) {
        if (value.length != largeValueBytes ||
            value.first >= values.length ||
            value.last != value.first ||
            !ids.add(value.first)) {
          throw StateError(
            'Invalid value in reopened 1 MiB benchmark database',
          );
        }
      }
      return reopen.elapsedMicroseconds;
    });
    return (write: write, reopen: reopenTime);
  } finally {
    await directory.delete(recursive: true);
  }
}
