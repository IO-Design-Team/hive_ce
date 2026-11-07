import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_storage_benchmark/test_model_adapter.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _name = 'test_box';
const _path = '$_name.hive';

void initHive() => Hive
  ..init('.')
  ..registerAdapter(TestModelAdapter());

Future<void> initIsolatedHive() async {
  await IsolatedHive.init('.');
  IsolatedHive.registerAdapter(TestModelAdapter());
}

final hive = _target(
  'Hive CE',
  () => Hive.openBox<TestModel>(_name),
  readAll: (box) => box.values.toList(),
);

final hiveEncrypted = _target(
  'Hive CE (encrypted)',
  () => Hive.openBox<TestModel>(
    _name,
    encryptionCipher: HiveAesCipher(List.generate(32, (i) => i)),
  ),
  readAll: (box) => box.values.toList(),
);

/// Opening a lazy box only loads its keys
final hiveLazy = _target(
  'Hive CE (lazy)',
  () => Hive.openLazyBox<TestModel>(_name),
  readAll: (box) => box.keys.toList(),
);

/// Reads every value of a lazy box with `getAt`
final hiveLazyValues = _target(
  'Hive CE (lazy)',
  () => Hive.openLazyBox<TestModel>(_name),
  readAll: (box) async => [
    for (var i = 0; i < box.length; i++) await box.getAt(i),
  ],
);

final isolatedHive = Target.create(
  name: 'IsolatedHive',
  path: _path,
  open: () => IsolatedHive.openBox<TestModel>(_name),
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: (box) async => (await box.values).toList(),
  close: (box) => box.close(),
);

Target _target<T extends BoxBase<TestModel>>(
  String name,
  Future<T> Function() open, {
  required FutureOr<List<Object?>> Function(T box) readAll,
}) => Target.create(
  name: name,
  path: _path,
  open: open,
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: readAll,
  close: (box) => box.close(),
);
