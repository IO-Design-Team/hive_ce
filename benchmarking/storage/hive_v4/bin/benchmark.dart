import 'package:common_storage_benchmark/db_type.dart';
import 'package:common_storage_benchmark/test_model.dart';
import 'package:common_storage_benchmark/benchmark.dart';
import 'package:hive/hive.dart';
import 'package:isar/isar.dart';

void main() async {
  await Isar.initialize('assets/libisar_macos.dylib');

  Hive.defaultDirectory = '.';
  Hive.registerAdapter('TestModel', (json) => TestModel.fromJson(json));

  await runBenchmark(
    type: DbType.hive,
    openBox: (name) => Hive.box(name: name),
  );
}
