import 'dart:async';

import 'package:storage_benchmark/db_type.dart';
import 'package:meta/meta.dart';

@immutable
class BenchTarget {
  final String name;
  final DbType type;
  final FutureOr<dynamic> Function(String name) openBox;
  final FutureOr<void> Function(dynamic box) readAll;

  const BenchTarget({
    required this.name,
    required this.type,
    required this.openBox,
    required this.readAll,
  });
}
