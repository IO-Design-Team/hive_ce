import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _name = 'test_box';
const _path = '$_name.hive';

/// Hive has no query API, so queries filter the values in memory
final hive = _target(
  'Hive CE',
  () => Hive.openBox<TestModel>(_name),
  openLarge: _largeBox(
    (path) => Hive.openBox<Uint8List>(_name, path: path),
    (box) => box.values.toList(),
  ),
  readAll: (box) => box.values.toList(),
  query: (box, min, max) => modelsInRange(box.values, min, max),
);

final hiveLazy = _target(
  'Hive CE (lazy)',
  () => Hive.openLazyBox<TestModel>(_name),
  openLarge: _largeBox(
    (path) => Hive.openLazyBox<Uint8List>(_name, path: path),
    (box) => _readLazy(box.length, box.getAt),
  ),
  readKeys: (box) => box.keys.toList(),
  readAll: (box) => _readLazy(box.length, box.getAt),
  query: (box, min, max) => _queryValues(box.length, box.getAt, min, max),
);

final isolatedHive = Target.create(
  name: 'IsolatedHive',
  path: _path,
  openLarge: _isolatedLargeBox(
    (path) => IsolatedHive.openBox<Uint8List>(_name, path: path),
    (box) async => (await box.values).toList(),
  ),
  open: () => IsolatedHive.openBox<TestModel>(_name),
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: (box) async => (await box.values).toList(),
  query: (box, min, max) async => modelsInRange(await box.values, min, max),
  close: (box) => box.close(),
);

final isolatedHiveLazy = Target.create(
  name: 'IsolatedHive (lazy)',
  path: _path,
  openLarge: _isolatedLargeBox(
    (path) => IsolatedHive.openLazyBox<Uint8List>(_name, path: path),
    (box) async => await _readLazy(await box.length, box.getAt),
  ),
  open: () => IsolatedHive.openLazyBox<TestModel>(_name),
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readKeys: (box) async => (await box.keys).toList(),
  readAll: (box) async => await _readLazy(await box.length, box.getAt),
  query: (box, min, max) async =>
      await _queryValues(await box.length, box.getAt, min, max),
  close: (box) => box.close(),
);

Future<List<T>> _readLazy<T>(
  int length,
  Future<T?> Function(int index) getAt,
) async => [for (var i = 0; i < length; i++) ?await getAt(i)];

Future<List<TestModel>> _queryValues(
  int length,
  Future<TestModel?> Function(int index) getAt,
  int min,
  int max,
) async {
  final matches = <TestModel>[];
  final started = Stopwatch()..start();
  for (var i = 0; i < length; i++) {
    if (started.elapsed >= timeLimit) throw TimeLimitExceeded();
    final value = await getAt(i);
    if (value != null && value.matchesRange(min, max)) {
      matches.add(value);
    }
  }
  return matches;
}

Target _target<T extends BoxBase<TestModel>>(
  String name,
  Future<T> Function() open, {
  required OpenLargeDatabase openLarge,
  required FutureOr<List<Object?>> Function(T box) readAll,
  required FutureOr<List<Object?>> Function(T box, int min, int max) query,
  FutureOr<List<Object?>> Function(T box)? readKeys,
}) => Target.create(
  name: name,
  openLarge: openLarge,
  path: _path,
  open: open,
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: readAll,
  readKeys: readKeys,
  query: query,
  close: (box) => box.close(),
);

OpenLargeDatabase _largeBox<T extends BoxBase<Uint8List>>(
  Future<T> Function(String path) open,
  FutureOr<List<Uint8List>> Function(T box) readAll,
) => largeDatabase(
  open: open,
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: readAll,
  close: (box) => box.close(),
);

OpenLargeDatabase _isolatedLargeBox<T extends IsolatedBoxBase<Uint8List>>(
  Future<T> Function(String path) open,
  Future<List<Uint8List>> Function(T box) readAll,
) => largeDatabase(
  open: open,
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: readAll,
  close: (box) => box.close(),
);
