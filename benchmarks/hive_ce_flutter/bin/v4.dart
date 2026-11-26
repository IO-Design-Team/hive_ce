import 'package:flutter/widgets.dart';
import 'package:hive_v4_storage_benchmark/targets.dart' as hive_v4;
import 'package:storage_benchmark/runner.dart';

// Built separately because Hive v2 and v4 resolve the same package name.
Future<void> main() => runBenchmarks(
  targets: [hive_v4.hive],
  initialize: WidgetsFlutterBinding.ensureInitialized,
);
