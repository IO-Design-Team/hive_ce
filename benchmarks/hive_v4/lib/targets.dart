import 'package:hive/hive.dart';
import 'package:isar/isar.dart';
import 'package:storage_benchmark/target.dart';
import 'package:storage_benchmark/test_model.dart';

const _name = 'test_box';

Future<void> initHive() async {
  await Isar.initialize('assets/libisar_macos.dylib');
  Hive.defaultDirectory = '.';
  Hive.registerAdapter('TestModel', (json) => TestModel.fromJson(json));
}

/// `add` and `addAll` commit to disk before they return, so there is no flush
final hive = Target.create(
  name: 'Hive v4',
  path: '$_name.isar',
  open: () => Hive.box<TestModel>(name: _name, maxSizeMiB: 1024),
  add: (box, value) => box.add(value),
  addAll: (box, values) => box.addAll(values),
  readAll: (box) => box.getRange(0, box.length),
  close: (box) => box.close(),
);
