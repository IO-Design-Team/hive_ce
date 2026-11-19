import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive_v2_storage_benchmark/test_model_adapter.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _name = 'test_box';

void initHive() {
  Hive.init('.');
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TestModelAdapter());
  }
}

/// Hive has no query API, so queries filter the values in memory
final hive = Target.create(
  name: 'Hive v2',
  path: '$_name.hive',
  initialize: initHive,
  closeEngine: Hive.close,
  openLarge: largeDatabase(
    open: (path) => Hive.openBox<Uint8List>(_name, path: path),
    addAll: (box, values) => box.addAll(values),
    flush: (box) => box.flush(),
    readAll: (box) => box.values.toList(),
    close: (box) => box.close(),
  ),
  open: () => Hive.openBox<TestModel>(_name),
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  flush: (box) => box.flush(),
  readAll: (box) => box.values.toList(),
  query: (box, min, max) => modelsInRange(box.values, min, max),
  close: (box) => box.close(),
);
