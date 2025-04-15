import 'package:meta/meta.dart';

@immutable
class BenchResult {
  final Duration time;
  final double size;

  const BenchResult({
    required this.time,
    required this.size,
  });
}
