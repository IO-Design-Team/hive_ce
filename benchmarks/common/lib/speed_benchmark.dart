import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

@immutable
class SpeedTarget {
  final String name;

  /// The database file or directory
  final String path;

  /// Opens the database, creating it when [path] is missing
  final FutureOr<dynamic> Function() open;

  /// Writes [values] to an open database
  final FutureOr<void> Function(dynamic db, List<TestModel> values) writeAll;
  final FutureOr<void> Function(dynamic db) close;
  final FutureOr<List<Object?>> Function(dynamic db) readAll;

  const SpeedTarget({
    required this.name,
    required this.path,
    required this.open,
    required this.writeAll,
    required this.close,
    required this.readAll,
  });
}

/// Times batch writes and opening a database to read every value.
///
/// Writes the results to `speed_results.md`.
Future<void> runSpeedBenchmarks(List<SpeedTarget> targets) async {
  final batchResults = <List<Duration>>[];
  final openResults = <List<Duration>>[];
  for (final count in operations) {
    batchResults.add([
      for (final target in targets) await _benchmarkBatchWrite(target, count),
    ]);
    openResults.add([
      for (final target in targets) await _benchmarkOpen(target, count),
    ]);
  }

  final names = [for (final target in targets) target.name];
  final results = [
    '### Batch writes',
    formatTable(names, [
      for (final row in batchResults) row.map(_formatTime).toList(),
    ]),
    '### Opening a box',
    formatTable(names, [
      for (final row in openResults) row.map(_formatTime).toList(),
    ]),
  ];

  File('speed_results.md').writeAsStringSync('${results.join('\n\n')}\n');
}

/// Writes [count] values in a single batch. The database is already open.
Future<Duration> _benchmarkBatchWrite(SpeedTarget target, int count) {
  final values = List.filled(count, testModel);
  late dynamic db;
  return _average(
    '$count operation ${target.name} batch write',
    setup: () async {
      _deleteDatabase(target.path);
      db = await target.open();
    },
    run: () async => await target.writeAll(db, values),
    teardown: () async => await target.close(db),
  );
}

/// Opens a database containing [count] values and reads all of them
Future<Duration> _benchmarkOpen(SpeedTarget target, int count) async {
  _deleteDatabase(target.path);
  final populated = await target.open();
  await target.writeAll(populated, List.filled(count, testModel));
  await target.close(populated);

  late dynamic db;
  return await _average(
    '$count operation ${target.name} open',
    run: () async {
      db = await target.open();
      final values = await target.readAll(db);
      if (values.length != count) {
        throw StateError('Read ${values.length} values, expected $count');
      }
    },
    teardown: () async => await target.close(db),
  );
}

Future<Duration> _average(
  String description, {
  int passes = 5,
  Future<void> Function()? setup,
  required Future<void> Function() run,
  required Future<void> Function() teardown,
}) async {
  var total = Duration.zero;
  for (var pass = 1; pass <= passes; pass++) {
    print('\nRunning $description benchmark pass $pass...');
    await setup?.call();
    final stopwatch = Stopwatch()..start();
    await run();
    final elapsed = stopwatch.elapsed;
    await teardown();
    print('Time: $elapsed');
    total += elapsed;
  }

  final average = total ~/ passes;
  print('\nAverage time: $average');
  return average;
}

void _deleteDatabase(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.directory) {
    Directory(path).deleteSync(recursive: true);
  } else if (type != FileSystemEntityType.notFound) {
    File(path).deleteSync();
  }
}

String _formatTime(Duration duration) {
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds} ms';
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s';
}
