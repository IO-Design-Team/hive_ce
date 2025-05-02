import 'package:hive_ce/src/util/debug_utils.dart';

const _allowedIterableTypes = {
  '<int>',
  '<double>',
  '<bool>',
  '<String>',
  '<dynamic>',
};

/// Check if E is a typed map or iterable
void typedMapOrIterableCheck<E>() {
  if (!kDebugMode) return;

  final type = E.toString();
  if (type.startsWith('Map<') && type != 'Map<dynamic, dynamic>') {
    throw AssertionError(
      'Cannot open a box of type $type. It is not possible to read typed Maps. Use Map.cast<RK, RV>() after reading.',
    );
  } else if ({'Iterable<', 'List<', 'Set<'}.any(type.startsWith) &&
      !_allowedIterableTypes.any(type.endsWith)) {
    throw AssertionError(
      'Cannot open a box of type $type. It is not possible to read Iterables of custom types. Use Iterable.cast<R>() after reading.',
    );
  }
}
