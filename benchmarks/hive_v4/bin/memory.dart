import 'package:hive_v4_storage_benchmark/targets.dart';
import 'package:storage_benchmark/memory_benchmark.dart';

void main(List<String> args) async {
  await initHive();
  await runMemoryBenchmarks(args, [hive]);
}
