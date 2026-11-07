import 'package:hive/hive.dart';
import 'package:hive_v4_storage_benchmark/targets.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() async {
  await initHive();
  await runSpeedBenchmarks(writes: [hive], batchWrites: [hive], opens: [hive]);
  Hive.closeAllBoxes();
}
