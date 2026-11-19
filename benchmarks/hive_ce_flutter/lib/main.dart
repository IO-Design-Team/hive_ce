import 'dart:io';

import 'package:drift_storage_benchmark/targets.dart' as drift_db;
import 'package:flutter/widgets.dart';
import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:hive_ce_storage_benchmark/targets.dart' as ce;
import 'package:hive_ce_storage_benchmark/test_model_adapter.dart';
import 'package:hive_v2_storage_benchmark/targets.dart' as hive_v2_bench;
import 'package:objectbox_storage_benchmark/targets.dart' as objectbox;
import 'package:sembast_storage_benchmark/targets.dart' as sembast_db;
import 'package:sqflite_storage_benchmark/targets.dart' as sqlite;
import 'package:storage_benchmark/runner.dart';

Future<void> _initHive() async {
  await Hive.initFlutter(Directory.current.absolute.path);
  if (Crc32.nativeCompute == null) {
    throw StateError('initFlutter did not install zlib');
  }
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TestModelAdapter());
  }
}

Future<void> _initIsolatedHive() async {
  await IsolatedHive.initFlutter(subDirectory: Directory.current.absolute.path);
  if (Crc32.nativeCompute == null) {
    throw StateError('initFlutter did not install zlib');
  }
  if (!IsolatedHive.isAdapterRegistered(0)) {
    IsolatedHive.registerAdapter(TestModelAdapter());
  }
}

final _targets = [
  ce.hive.withLifecycle(initialize: _initHive, close: Hive.close),
  ce.hiveLazy.withLifecycle(initialize: _initHive, close: Hive.close),
  ce.isolatedHive.withLifecycle(
    initialize: _initIsolatedHive,
    close: IsolatedHive.close,
  ),
  ce.isolatedHiveLazy.withLifecycle(
    initialize: _initIsolatedHive,
    close: IsolatedHive.close,
  ),
  hive_v2_bench.hive,
  sqlite.sqflite,
  drift_db.drift,
  sembast_db.sembast,
  objectbox.objectBox,
];

Future<void> main() => runBenchmarks(
  targets: _targets,
  initialize: WidgetsFlutterBinding.ensureInitialized,
);
