import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/connect/hive_connect_api.dart';

/// An inspectable box
abstract interface class InspectableBox {
  /// The name of the box
  String get name;

  /// Returns all of the frames currently loaded in the box
  Future<Iterable<InspectorFrame>> getFrames();

  /// Returns the value for the given [key].
  Future<Object?> loadValue(Object key);

  /// Watch the box for changes
  Stream<BoxEvent> watch();
}
