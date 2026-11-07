import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_storage_benchmark/test_model_adapter.dart';
import 'package:storage_benchmark/bench_target.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/db_type.dart';

void main() async {
  Hive
    ..init('.')
    ..registerAdapter(TestModelAdapter());

  await IsolatedHive.init('.');
  IsolatedHive.registerAdapter(TestModelAdapter());

  final cipher = HiveAesCipher(List.generate(32, (i) => i));

  final hive = BenchTarget(
    name: 'Hive CE',
    type: DbType.hive,
    openBox: Hive.openBox,
    readAll: (box) => box.values.toList(),
    flush: (box) => box.flush(),
  );
  final hiveEncrypted = BenchTarget(
    name: 'Hive CE (encrypted)',
    type: DbType.hive,
    openBox: (name) => Hive.openBox(name, encryptionCipher: cipher),
    readAll: (box) => box.values.toList(),
    flush: (box) => box.flush(),
  );
  final hiveLazy = BenchTarget(
    name: 'Hive CE (lazy)',
    type: DbType.hive,
    openBox: Hive.openLazyBox,
    readAll: (box) {},
    flush: (box) => box.flush(),
  );
  final isolatedHive = BenchTarget(
    name: 'IsolatedHive',
    type: DbType.hive,
    openBox: IsolatedHive.openBox,
    readAll: (box) async => (await box.values).toList(),
    flush: (box) => box.flush(),
  );

  await runBenchmarks(
    writeTargets: [hive, isolatedHive],
    batchTargets: [hive, hiveEncrypted, isolatedHive],
    openTargets: [hive, hiveEncrypted, hiveLazy, isolatedHive],
  );

  await Hive.close();
  await IsolatedHive.close();
  exit(0);
}
