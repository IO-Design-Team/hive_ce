import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

/// Times writes and opening a database to read every value, and writes the
/// results to `speed_results.md`.
///
/// Write timings include [Target.flush], so they end when the data is on disk.
Future<void> runSpeedBenchmarks({
  List<Target> writes = const [],
  required List<Target> batchWrites,
  required List<Target> opens,
}) async {
  final writeTimes = <List<Duration>>[];
  final batchTimes = <List<Duration>>[];
  final openTimes = <List<Duration>>[];
  for (final count in operations) {
    writeTimes.add([for (final target in writes) await _write(target, count)]);
    batchTimes.add([
      for (final target in batchWrites) await _batchWrite(target, count),
    ]);
    openTimes.add([for (final target in opens) await _open(target, count)]);
  }

  writeResults('speed_results.md', {
    if (writes.isNotEmpty)
      'Individual writes': formatTable(writes, writeTimes, _formatTime),
    'Batch writes': formatTable(batchWrites, batchTimes, _formatTime),
    'Opening a database and reading every value': formatTable(
      opens,
      openTimes,
      _formatTime,
    ),
  });
}

/// Writes [count] values one at a time, flushing each before the next
Future<Duration> _write(Target target, int count) {
  final add = target.add ?? (throw ArgumentError('${target.name} has no add'));
  late Object? db;
  return _average(
    '$count value ${target.name} write',
    passes: count >= 100000 ? 2 : 5,
    setup: () async {
      deleteDatabase(target.path);
      db = await target.open();
    },
    run: () async {
      for (var i = 0; i < count; i++) {
        await add(db, testModel);
        await target.flush?.call(db);
      }
    },
    teardown: () => target.close(db),
  );
}

/// Writes [count] values in a single batch to a database that is already open
Future<Duration> _batchWrite(Target target, int count) {
  final values = List.filled(count, testModel);
  late Object? db;
  return _average(
    '$count value ${target.name} batch write',
    setup: () async {
      deleteDatabase(target.path);
      db = await target.open();
    },
    run: () async {
      await target.addAll(db, values);
      await target.flush?.call(db);
    },
    teardown: () => target.close(db),
  );
}

/// Opens a database containing [count] values and reads all of them
Future<Duration> _open(Target target, int count) async {
  await createDatabase(target, List.filled(count, testModel));
  late Object? db;
  return await _average(
    '$count value ${target.name} open',
    run: () async {
      db = await target.open();
      checkCount(await target.readAll(db), count);
    },
    teardown: () => target.close(db),
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

String _formatTime(Duration duration) {
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds} ms';
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s';
}
