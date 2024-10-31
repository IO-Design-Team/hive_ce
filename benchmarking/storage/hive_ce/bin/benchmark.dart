import 'package:common_storage_benchmark/db_type.dart';
import 'package:common_storage_benchmark/test_model.dart';
import 'package:common_storage_benchmark/benchmark.dart';
import 'package:hive_ce/hive.dart';

void main() async {
  Hive
    ..init('.')
    ..registerAdapter(TestModelAdapter());

  await runBenchmark(
    type: DbType.hive,
    openBox: Hive.openBox,
  );
}
