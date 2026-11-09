import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

/// Passes that take longer are stopped. The target is skipped for that value
/// count and every larger one.
const _timeLimit = Duration(minutes: 1);

/// Times writes, opening a database to read every value, and querying an open
/// database, and writes the results to `speed_results.md`.
///
/// Write timings include [Target.flush], so they end when the data is on disk.
Future<void> runSpeedBenchmarks({
  List<Target> writes = const [],
  required List<Target> batchWrites,
  required List<Target> opens,
  List<Target> queries = const [],
}) async {
  final writeTimes = await _run(writes, _write);
  final batchTimes = await _run(batchWrites, _batchWrite);
  final openTimes = await _run(opens, _open);
  final queryTimes = await _run(queries, _query);

  writeResults('speed_results.md', {
    if (writes.isNotEmpty)
      'Individual writes': formatTable(writes, writeTimes, _formatTime),
    if (batchWrites.isNotEmpty)
      'Batch writes': formatTable(batchWrites, batchTimes, _formatTime),
    if (opens.isNotEmpty)
      'Opening a database and reading every value': formatTable(
        opens,
        openTimes,
        _formatTime,
      ),
    if (queries.isNotEmpty)
      'Querying a tenth of the values': formatTable(
        queries,
        queryTimes,
        _formatTime,
      ),
  });
}

/// Runs [benchmark] for every target and value count. Returns `null` for
/// counts that hit [_timeLimit].
Future<List<List<Duration?>>> _run(
  List<Target> targets,
  Future<Duration?> Function(Target target, int count) benchmark,
) async {
  final overLimit = <Target>{};
  final results = <List<Duration?>>[];
  for (final count in operations) {
    final row = <Duration?>[];
    for (final target in targets) {
      if (overLimit.contains(target)) {
        print(
          '\nSkipping $count value ${target.name}: smaller count hit the time limit',
        );
        row.add(null);
        continue;
      }
      final time = await benchmark(target, count);
      if (time == null) overLimit.add(target);
      row.add(time);
    }
    results.add(row);
  }
  return results;
}

/// Writes [count] values one at a time, then flushes them once
Future<Duration?> _write(Target target, int count) {
  final add = target.add ?? (throw ArgumentError('${target.name} has no add'));
  final values = testModels(count);
  late Object? db;
  return _average(
    '$count value ${target.name} write',
    passes: count >= 100000 ? 2 : 5,
    setup: () async {
      deleteDatabase(target.path);
      db = await target.open();
    },
    run: (stopwatch) async {
      for (final value in values) {
        if (stopwatch.elapsed > _timeLimit) return;
        await add(db, value);
      }
      await target.flush?.call(db);
    },
    teardown: () => target.close(db),
  );
}

/// Writes [count] values in a single batch to a database that is already open
Future<Duration?> _batchWrite(Target target, int count) {
  final values = testModels(count);
  late Object? db;
  return _average(
    '$count value ${target.name} batch write',
    setup: () async {
      deleteDatabase(target.path);
      db = await target.open();
    },
    run: (_) async {
      await target.addAll(db, values);
      await target.flush?.call(db);
    },
    teardown: () => target.close(db),
  );
}

/// Opens a database containing [count] values and reads all of them
Future<Duration?> _open(Target target, int count) async {
  await createDatabase(target, testModels(count));
  late Object? db;
  return await _average(
    '$count value ${target.name} open',
    run: (_) async {
      db = await target.open();
      checkCount(await target.readAll(db), count);
    },
    teardown: () => target.close(db),
  );
}

/// Opens a database containing [count] values, then times one query for a
/// contiguous tenth of them. Databases that support indexes index the queried
/// field.
Future<Duration?> _query(Target target, int count) async {
  final query =
      target.query ?? (throw ArgumentError('${target.name} has no query'));
  await createDatabase(target, testModels(count));
  final min = count ~/ 2;
  final max = min + count ~/ 10;
  late Object? db;
  return await _average(
    '$count value ${target.name} query',
    setup: () async {
      db = await target.open();
    },
    run: (_) async => checkCount(await query(db, min, max), max - min),
    teardown: () => target.close(db),
  );
}

/// Returns `null` if a pass takes longer than [_timeLimit]
Future<Duration?> _average(
  String description, {
  int passes = 5,
  Future<void> Function()? setup,
  required Future<void> Function(Stopwatch stopwatch) run,
  required Future<void> Function() teardown,
}) async {
  var total = Duration.zero;
  for (var pass = 1; pass <= passes; pass++) {
    print('\nRunning $description benchmark pass $pass...');
    await setup?.call();
    final stopwatch = Stopwatch()..start();
    await run(stopwatch);
    final elapsed = stopwatch.elapsed;
    await teardown();
    if (elapsed > _timeLimit) {
      print('Stopped after $elapsed: over the $_timeLimit time limit');
      return null;
    }
    print('Time: $elapsed');
    total += elapsed;
  }

  final average = total ~/ passes;
  print('\nAverage time: $average');
  return average;
}

String _formatTime(Duration? duration) {
  if (duration == null) return '> ${_timeLimit.inMinutes} min';
  if (duration.inMilliseconds < 1) return '${duration.inMicroseconds} µs';
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds} ms';
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s';
}
