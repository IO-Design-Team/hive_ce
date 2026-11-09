import 'package:hive/hive.dart';
import 'package:hive_v2_storage_benchmark/targets.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() async {
  initHive();

  await runSpeedBenchmarks(
    writes: [hive],
    batchWrites: [hive, hiveEncrypted],
    opens: [hive, hiveEncrypted, hiveLazy],
    queries: [hive],
  );

  await Hive.close();
}
