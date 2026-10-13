import 'dart:typed_data';

import 'package:hive_ce/src/hive_error.dart';

/// Not part of public API
void rejectUnsupportedCollectionValue(Object value) {
  if (value is Uint8List) return;
  if ((value is Iterable && value is! List) ||
      value is List<num> ||
      value is List<bool> ||
      value is List<String>) {
    throw HiveError(
      'CollectionBox does not support typed lists, sets, or other iterables. '
      'Use List<dynamic> instead.',
    );
  }
}
