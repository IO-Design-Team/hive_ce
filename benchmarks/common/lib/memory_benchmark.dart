import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

const _passes = 3;

@immutable
class MemoryTarget {
  final String name;

  /// The database file or directory
  final String path;

  /// Creates a database containing [values] and closes it
  final FutureOr<void> Function(List<TestModel> values) write;
  final FutureOr<dynamic> Function() open;
  final FutureOr<List<Object?>> Function(dynamic db) readAll;

  const MemoryTarget({
    required this.name,
    required this.path,
    required this.write,
    required this.open,
    required this.readAll,
  });
}

/// Runs every memory benchmark and writes the results to `memory_results.md`
///
/// Peak RSS never decreases, so every measurement runs in a new process
Future<void> runMemoryBenchmarks(
  List<String> args,
  List<MemoryTarget> targets,
) async {
  if (args.isNotEmpty) {
    await _measure(targets, args);
    exit(0);
  }

  final writeResults = <List<int>>[];
  final openResults = <List<int>>[];
  final readResults = <List<int>>[];
  for (final count in operations) {
    final writeRow = <int>[];
    final openRow = <int>[];
    final readRow = <int>[];
    for (var i = 0; i < targets.length; i++) {
      final name = targets[i].name;
      final [write] = await _average('$count value $name write', [
        'write',
        '$i',
        '$count',
      ]);
      final [open, read] = await _average('$count value $name open', [
        'open',
        '$i',
        '$count',
      ]);
      writeRow.add(write);
      openRow.add(open);
      readRow.add(read);
    }
    writeResults.add(writeRow);
    openResults.add(openRow);
    readResults.add(readRow);
  }

  final names = [for (final target in targets) target.name];
  String table(List<List<int>> results) => formatTable(names, [
    for (final row in results) row.map(_formatBytes).toList(),
  ]);

  final results = [
    '### Batch writes',
    table(writeResults),
    '### Opening a database',
    table(openResults),
    '### Opening a database and reading every value',
    table(readResults),
  ];

  File('memory_results.md').writeAsStringSync('${results.join('\n\n')}\n');
}

/// Prints the peak RSS increase of a single measurement
Future<void> _measure(List<MemoryTarget> targets, List<String> args) async {
  final [scenario, index, countArg] = args;
  final target = targets[int.parse(index)];
  final count = int.parse(countArg);

  switch (scenario) {
    case 'write':
      final type = FileSystemEntity.typeSync(target.path);
      if (type == FileSystemEntityType.directory) {
        Directory(target.path).deleteSync(recursive: true);
      } else if (type != FileSystemEntityType.notFound) {
        File(target.path).deleteSync();
      }

      final values = List.filled(count, testModel);
      final baseline = ProcessInfo.currentRss;
      await target.write(values);
      print(ProcessInfo.maxRss - baseline);
    case 'open':
      final baseline = ProcessInfo.currentRss;
      final db = await target.open();
      final open = ProcessInfo.maxRss - baseline;
      final values = await target.readAll(db);
      final read = ProcessInfo.maxRss - baseline;
      if (values.length != count) {
        throw StateError('Read ${values.length} values, expected $count');
      }
      print('$open $read');
  }
}

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
    print('Peak: ${peaks.map(_formatBytes).join(', ')}');
    passes.add(peaks);
  }

  return [
    for (var i = 0; i < passes.first.length; i++)
      passes.map((peaks) => peaks[i]).reduce((a, b) => a + b) ~/ _passes,
  ];
}

String _formatBytes(int bytes) =>
    '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
