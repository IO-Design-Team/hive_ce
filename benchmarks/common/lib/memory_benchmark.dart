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
/// Peak RSS never decreases, so every memory measurement runs in a new
/// process. Database size is the size of the database left by the batch write.
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
  final sizeResults = <List<int>>[];
  for (final count in operations) {
    final writeRow = <int>[];
    final openRow = <int>[];
    final readRow = <int>[];
    final sizeRow = <int>[];
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final [write] = await _average('$count value ${target.name} write', [
        'write',
        '$i',
        '$count',
      ]);
      final size = _databaseSize(target.path);
      print('Size: ${_formatSize(size)}');
      final [open, read] = await _average('$count value ${target.name} open', [
        'open',
        '$i',
        '$count',
      ]);
      writeRow.add(write);
      openRow.add(open);
      readRow.add(read);
      sizeRow.add(size);
    }
    writeResults.add(writeRow);
    openResults.add(openRow);
    readResults.add(readRow);
    sizeResults.add(sizeRow);
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
    '### Database size',
    formatTable(names, [
      for (final row in sizeResults) row.map(_formatSize).toList(),
    ]),
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

/// Bytes on disk for a database file, or every file in a database directory
int _databaseSize(String path) {
  if (FileSystemEntity.isDirectorySync(path)) {
    var size = 0;
    for (final entity in Directory(path).listSync(recursive: true)) {
      if (entity is File) size += entity.lengthSync();
    }
    return size;
  }
  return File(path).lengthSync();
}

String _formatBytes(int bytes) =>
    '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

String _formatSize(int bytes) =>
    '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
