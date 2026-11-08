import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_storage_benchmark/targets.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() async {
  initHive();
  await initIsolatedHive();

  await runSpeedBenchmarks(
    writes: [hive, isolatedHive],
    batchWrites: [hive, hiveEncrypted, isolatedHive],
    opens: [hive, hiveEncrypted, hiveLazy, isolatedHive],
  );

  await Hive.close();
  await IsolatedHive.close();
  exit(0);
}
