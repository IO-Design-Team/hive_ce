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
      'Cannot open a box of type $type. Instead open a `Box<Map>` and call `getMap<K, V>()`.',
    );
  } else if ({'Iterable<', 'List<', 'Set<'}.any(type.startsWith) &&
      !_allowedIterableTypes.any(type.endsWith)) {
    final iterableType = type.substring(0, type.indexOf('<'));
    throw AssertionError(
      'Cannot open a box of type $type. Instead open a `Box<$iterableType>` and call `get$iterableType<T>()`.',
    );
  }
}

/// Common logic for casting a typed list
List<T>? castList<T>(Object? value, {List<T>? defaultValue}) {
  if (value != null) {
    return (value as List).cast<T>();
  } else {
    return defaultValue;
  }
}

/// Common logic for casting a typed set
Set<T>? castSet<T>(Object? value, {Set<T>? defaultValue}) {
  if (value != null) {
    return (value as Set).cast<T>();
  } else {
    return defaultValue;
  }
}

/// Common logic for casting a typed map
Map<K, V>? castMap<K, V>(Object? value, {Map<K, V>? defaultValue}) {
  if (value != null) {
    return (value as Map).cast<K, V>();
  } else {
    return defaultValue;
  }
}
