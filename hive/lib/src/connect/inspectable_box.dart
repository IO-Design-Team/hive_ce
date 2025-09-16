import 'dart:async';

import 'package:hive_ce/hive.dart';

/// An inspectable box
abstract interface class InspectableBox {
  /// The name of the box
  String get name;

  /// The box's type registry
  TypeRegistry get typeRegistry;

  /// All the keys in the box
  FutureOr<Iterable<dynamic>> get keys;

  /// Returns the value for the given [key].
  FutureOr<Object?> get(Object key);

  /// Watch the box for changes
  Stream<BoxEvent> watch();
}
