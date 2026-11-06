import 'dart:async';
import 'dart:io';

import 'package:storage_benchmark/bench_result.dart';
import 'package:storage_benchmark/bench_target.dart';
import 'package:storage_benchmark/test_model.dart';

const _operations = [1000, 10000, 100000, 1000000];
const _boxName = 'test_box';
const _model = TestModel(
  testModelFieldZero: 0,
  testModelFieldOne: 1,
  testModelFieldTwo: 2,
  testModelFieldThree: 3,
  testModelFieldFour: 4,
  testModelFieldFive: 5,
  testModelFieldSix: 6,
  testModelFieldSeven: 7,
  testModelFieldEight: 8,
  testModelFieldNine: 9,
);

/// Runs every benchmark and writes the results to `results.md`
Future<void> runBenchmarks({
  required List<BenchTarget> writeTargets,
  required List<BenchTarget> batchTargets,
  required List<BenchTarget> openTargets,
}) async {
  final writeResults = <List<BenchResult>>[];
  final batchResults = <List<Duration>>[];
  final openResults = <List<Duration>>[];
  for (final operations in _operations) {
    writeResults.add([
      for (final target in writeTargets)
        await _benchmarkWrites(target, operations),
    ]);
    batchResults.add([
      for (final target in batchTargets)
        await _benchmarkBatchWrite(target, operations),
    ]);
    openResults.add([
      for (final target in openTargets)
        await _benchmarkOpen(target, operations),
    ]);
  }

  final results = [
    '### Individual writes',
    _formatTable(writeTargets, [
      for (final row in writeResults)
        [for (final r in row) _formatTime(r.time)],
    ]),
    '### Batch writes',
    _formatTable(batchTargets, [
      for (final row in batchResults) row.map(_formatTime).toList(),
    ]),
    '### Opening a box',
    _formatTable(openTargets, [
      for (final row in openResults) row.map(_formatTime).toList(),
    ]),
    '### Database size',
    _formatTable(writeTargets, [
      for (final row in writeResults)
        [for (final r in row) _formatSize(r.size)],
    ]),
  ];

  File('results.md').writeAsStringSync('${results.join('\n\n')}\n');
}

/// Writes [operations] values one at a time
Future<BenchResult> _benchmarkWrites(BenchTarget target, int operations) async {
  final boxFile = File(target.type.boxFileName(_boxName));
  late dynamic box;
  final time = await _average(
    '$operations operation ${target.name} write',
    passes: operations >= 100000 ? 2 : 5,
    setup: () async {
      _delete(boxFile);
      box = await target.openBox(_boxName);
    },
    run: () async {
      for (var i = 0; i < operations; i++) {
        await box.add(_model);
      }
    },
    teardown: () async => await box.close(),
  );

  final size = boxFile.lengthSync() / 1024 / 1024;
  print('Size: ${size.toStringAsFixed(2)} MB');
  return BenchResult(time: time, size: size);
}

/// Writes [operations] values in a single batch
Future<Duration> _benchmarkBatchWrite(BenchTarget target, int operations) {
  final boxFile = File(target.type.boxFileName(_boxName));
  final values = List.filled(operations, _model);
  late dynamic box;
  return _average(
    '$operations operation ${target.name} batch write',
    setup: () async {
      _delete(boxFile);
      box = await target.openBox(_boxName);
    },
    run: () async => await box.addAll(values),
    teardown: () async => await box.close(),
  );
}

/// Opens a box containing [operations] values and reads all of them
Future<Duration> _benchmarkOpen(BenchTarget target, int operations) async {
  final boxFile = File(target.type.boxFileName(_boxName));
  _delete(boxFile);
  var box = await target.openBox(_boxName);
  await box.addAll(List.filled(operations, _model));
  await box.close();

  return await _average(
    '$operations operation ${target.name} open',
    run: () async {
      box = await target.openBox(_boxName);
      await target.readAll(box);
    },
    teardown: () async => await box.close(),
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

void _delete(File file) {
  if (file.existsSync()) file.deleteSync();
}

String _formatTable(List<BenchTarget> targets, List<List<String>> cells) {
  final headers = ['Values', for (final target in targets) target.name];
  final rows = [
    for (var i = 0; i < cells.length; i++)
      [_formatCount(_operations[i]), ...cells[i]],
  ];
  final widths = [
    for (var i = 0; i < headers.length; i++)
      [
        headers[i],
        ...rows.map((row) => row[i]),
      ].map((cell) => cell.length).reduce((a, b) => a > b ? a : b),
  ];
  String formatRow(List<String> row) =>
      '| ${[for (var i = 0; i < row.length; i++) i == 0 ? row[i].padRight(widths[i]) : row[i].padLeft(widths[i])].join(' | ')} |';
  return [
    formatRow(headers),
    '| ${[for (var i = 0; i < widths.length; i++) i == 0 ? '-' * widths[i] : '${'-' * (widths[i] - 1)}:'].join(' | ')} |',
    ...rows.map(formatRow),
  ].join('\n');
}

String _formatCount(int count) => count.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _formatTime(Duration duration) {
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds} ms';
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s';
}

String _formatSize(double size) => '${size.toStringAsFixed(2)} MB';
