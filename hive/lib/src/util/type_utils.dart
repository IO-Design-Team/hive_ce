import 'package:hive_ce/src/util/debug_utils.dart';

/// Check if E is a typed map or iterable
void typedMapOrIterableCheck<E>() {
  if (!kDebugMode) return;

  final type = E.toString();
  if (type.startsWith('Map<') && type != 'Map<dynamic, dynamic>') {
    throw AssertionError(
      'Cannot open a box of type $type. It is not possible to read typed Maps. Use Map.cast<RK, RV>() after reading.',
    );
  } else if ({'Iterable<', 'List<', 'Set<'}.any(type.startsWith) &&
      !type.endsWith('<dynamic>')) {
    throw AssertionError(
      'Cannot open a box of type $type. It is not possible to read typed Iterables. Use Iterable.cast<R>() after reading.',
    );
  }
}
