import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:meta/meta.dart';

/// Not part of public API
@immutable
class ChangeNotifier {
  final StreamController<BoxEvent> _streamController;

  /// Not part of public API
  ChangeNotifier() : _streamController = StreamController<BoxEvent>.broadcast();

  /// Not part of public API
  @visibleForTesting
  const ChangeNotifier.debug(this._streamController);

  /// Not part of public API
  void notify(Frame frame) {
    _streamController.add(BoxEvent(frame.key, frame.value, frame.deleted));
  }

  /// Not part of public API
  Stream<BoxEvent> watch({dynamic key}) {
    if (key != null) {
      return _streamController.stream.where((it) => it.key == key);
    } else {
      return _streamController.stream;
    }
  }

  /// Not part of public API
  Future<void> close() {
    return _streamController.close();
  }
}
