import 'package:hive/hive.dart';
import 'package:hive_v2_storage_benchmark/test_model_adapter.dart';
import 'package:storage_benchmark/bench_target.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/db_type.dart';

void main() async {
  Hive
    ..init('.')
    ..registerAdapter(TestModelAdapter());

  final cipher = HiveAesCipher(List.generate(32, (i) => i));

  final hive = BenchTarget(
    name: 'Hive v2',
    type: DbType.hive,
    openBox: Hive.openBox,
    readAll: (box) => box.values.toList(),
    flush: (box) => box.flush(),
  );
  final hiveEncrypted = BenchTarget(
    name: 'Hive v2 (encrypted)',
    type: DbType.hive,
    openBox: (name) => Hive.openBox(name, encryptionCipher: cipher),
    readAll: (box) => box.values.toList(),
    flush: (box) => box.flush(),
  );
  final hiveLazy = BenchTarget(
    name: 'Hive v2 (lazy)',
    type: DbType.hive,
    openBox: Hive.openLazyBox,
    readAll: (box) {},
    flush: (box) => box.flush(),
  );

  await runBenchmarks(
    writeTargets: [hive],
    batchTargets: [hive, hiveEncrypted],
    openTargets: [hive, hiveEncrypted, hiveLazy],
  );

  await Hive.close();
}
