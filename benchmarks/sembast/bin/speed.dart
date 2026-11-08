import 'package:sembast_storage_benchmark/targets.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() => runSpeedBenchmarks(
  writes: [sembast],
  batchWrites: [sembast],
  opens: [sembast],
);
