import 'package:objectbox_storage_benchmark/targets.dart';
import 'package:storage_benchmark/speed_benchmark.dart';

void main() => runSpeedBenchmarks(batchWrites: [objectBox], opens: [objectBox]);
