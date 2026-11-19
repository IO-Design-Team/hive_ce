import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:isar/isar.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _name = 'test_box';

var _initialized = false;

Future<void> initHive() async {
  if (_initialized) return;
  _initialized = true;
  final dylib = [
    'assets/libisar_macos.dylib',
    '../hive_v4/assets/libisar_macos.dylib',
  ].firstWhere((path) => File(path).existsSync());
  await Isar.initialize(dylib);
  Hive.defaultDirectory = '.';
  Hive.registerAdapter('TestModel', (json) => TestModel.fromJson(json));
}

/// `add` and `addAll` commit to disk before they return, so there is no flush.
/// There is no query API, so queries read every value and filter them.
final hive = Target.create(
  name: 'Hive v4',
  path: '$_name.isar',
  initialize: initHive,
  closeEngine: Hive.closeAllBoxes,
  // Hive v4 stores JSON values. Encode bytes as a base64 string.
  openLarge: largeDatabase(
    open: (path) =>
        Hive.box<String>(name: _name, directory: path, maxSizeMiB: 1024),
    addAll: (box, values) => box.addAll(values.map(base64Encode).toList()),
    readAll: (box) => box.getRange(0, box.length).map(base64Decode).toList(),
    close: (box) => box.close(),
  ),
  open: () => Hive.box<TestModel>(name: _name, maxSizeMiB: 1024),
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  readAll: (box) => box.getRange(0, box.length),
  query: (box, min, max) =>
      modelsInRange(box.getRange(0, box.length), min, max),
  close: (box) => box.close(),
);
