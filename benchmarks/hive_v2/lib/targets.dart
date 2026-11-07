import 'dart:async';

import 'package:hive/hive.dart';
import 'package:hive_v2_storage_benchmark/test_model_adapter.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _name = 'test_box';

void initHive() => Hive
  ..init('.')
  ..registerAdapter(TestModelAdapter());

final hive = _target(
  'Hive v2',
  () => Hive.openBox<TestModel>(_name),
  readAll: (box) => box.values.toList(),
);

final hiveEncrypted = _target(
  'Hive v2 (encrypted)',
  () => Hive.openBox<TestModel>(
    _name,
    encryptionCipher: HiveAesCipher(List.generate(32, (i) => i)),
  ),
  readAll: (box) => box.values.toList(),
);

/// Opening a lazy box only loads its keys
final hiveLazy = _target(
  'Hive v2 (lazy)',
  () => Hive.openLazyBox<TestModel>(_name),
  readAll: (box) => box.keys.toList(),
);

Target _target<T extends BoxBase<TestModel>>(
  String name,
  Future<T> Function() open, {
  required FutureOr<List<Object?>> Function(T box) readAll,
}) => Target.create(
  name: name,
  path: '$_name.hive',
  open: open,
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: readAll,
  close: (box) => box.close(),
);
