import 'package:drift_storage_benchmark/targets.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() => runSpeedBenchmarks(
  writes: [drift],
  batchWrites: [drift],
  opens: [drift],
  queries: [drift],
);
