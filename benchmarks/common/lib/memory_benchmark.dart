import 'dart:io';

import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _passes = 3;

/// Measures peak memory and database size, and writes the results to
/// `memory_results.md`.
///
/// Peak RSS never decreases, so every memory measurement runs in a new
/// process. The process is this executable, called with [args] naming the
/// measurement. Database size is the size of the database left by the batch
/// write.
Future<void> runMemoryBenchmarks(
  List<String> args,
  List<Target> targets,
) async {
  if (args.isNotEmpty) {
    await _measure(targets, args);
    exit(0);
  }

  final writePeaks = <List<int>>[];
  final openPeaks = <List<int>>[];
  final readPeaks = <List<int>>[];
  final sizes = <List<int>>[];
  for (final count in operations) {
    final writeRow = <int>[];
    final openRow = <int>[];
    final readRow = <int>[];
    final sizeRow = <int>[];
    for (var i = 0; i < targets.length; i++) {
      final name = targets[i].name;
      final [write] = await _average('$count value $name write', [
        'write',
        '$i',
        '$count',
      ]);
      final size = databaseSize(targets[i].path);
      print('Size: ${formatMegabytes(size)}');
      final [open, read] = await _average('$count value $name open', [
        'open',
        '$i',
        '$count',
      ]);
      writeRow.add(write);
      openRow.add(open);
      readRow.add(read);
      sizeRow.add(size);
    }
    writePeaks.add(writeRow);
    openPeaks.add(openRow);
    readPeaks.add(readRow);
    sizes.add(sizeRow);
  }

  writeResults('memory_results.md', {
    'Batch writes': formatTable(targets, writePeaks, _formatPeak),
    'Opening a database': formatTable(targets, openPeaks, _formatPeak),
    'Opening a database and reading every value': formatTable(
      targets,
      readPeaks,
      _formatPeak,
    ),
    'Database size': formatTable(targets, sizes, formatMegabytes),
  });
}

/// Prints the peak RSS increase of a single measurement
Future<void> _measure(List<Target> targets, List<String> args) async {
  final [scenario, index, countArg] = args;
  final target = targets[int.parse(index)];
  final count = int.parse(countArg);

  switch (scenario) {
    case 'write':
      final values = testModels(count);
      final baseline = ProcessInfo.currentRss;
      await createDatabase(target, values);
      print(ProcessInfo.maxRss - baseline);
    case 'open':
      final baseline = ProcessInfo.currentRss;
      final db = await target.open();
      final open = ProcessInfo.maxRss - baseline;
      final values = await target.readAll(db);
      final read = ProcessInfo.maxRss - baseline;
      checkCount(values, count);
      print('$open $read');
  }
}

/// Runs a measurement [_passes] times and averages each printed peak
Future<List<int>> _average(String description, List<String> args) async {
  final executable = Platform.resolvedExecutable;
  final scriptArgs = [
    if (!const bool.fromEnvironment('dart.vm.product'))
      Platform.script.toFilePath(),
  ];

  final passes = <List<int>>[];
  for (var pass = 1; pass <= _passes; pass++) {
    print('\nRunning $description memory benchmark pass $pass...');
    final result = await Process.run(executable, [...scriptArgs, ...args]);
    if (result.exitCode != 0) {
      throw Exception('$description failed:\n${result.stdout}${result.stderr}');
    }

    final output = (result.stdout as String).trim().split('\n').last;
    final peaks = output.split(' ').map(int.parse).toList();
    print('Peak: ${peaks.map(_formatPeak).join(', ')}');
    passes.add(peaks);
  }

  return [
    for (var i = 0; i < passes.first.length; i++)
      passes.map((peaks) => peaks[i]).reduce((a, b) => a + b) ~/ _passes,
  ];
}

String _formatPeak(int bytes) => formatMegabytes(bytes, digits: 1);
