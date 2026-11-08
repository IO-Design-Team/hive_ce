import 'package:hive_v2_storage_benchmark/targets.dart';
import 'package:storage_benchmark/memory_benchmark.dart';

void main(List<String> args) async {
  initHive();
  await runMemoryBenchmarks(args, [hive]);
}
