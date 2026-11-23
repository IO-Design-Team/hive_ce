import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:meta/meta.dart';

/// Not part of public API
@immutable
class ChangeNotifier {
  final StreamController<BoxEvent> _streamController;
  final _keyControllers = <dynamic, StreamController<BoxEvent>>{};

  /// Not part of public API
  ChangeNotifier() : _streamController = StreamController<BoxEvent>.broadcast();

  /// Not part of public API
  @visibleForTesting
  ChangeNotifier.debug(this._streamController);

  /// Not part of public API
  @visibleForTesting
  int get keyControllerCount => _keyControllers.length;

  /// Not part of public API
  void notify(Frame frame, {Object? deletedValue}) {
    final hasGlobal = _streamController.hasListener;
    final keyController =
        _keyControllers.isNotEmpty ? _keyControllers[frame.key] : null;
    final hasKey = keyController != null && keyController.hasListener;
    if (!hasGlobal && !hasKey) return;

    final event = BoxEvent(
      frame.key,
      frame.deleted ? deletedValue : frame.value,
      frame.deleted,
    );
    if (hasGlobal) {
      _streamController.add(event);
    }
    if (hasKey && !keyController.isClosed) {
      keyController.add(event);
    }
  }

  /// Not part of public API
  Stream<BoxEvent> watch({dynamic key}) {
    if (key != null) {
      final controller = _keyControllers.putIfAbsent(
        key,
        () {
          late final StreamController<BoxEvent> c;
          c = StreamController<BoxEvent>.broadcast(
            onCancel: () {
              if (!c.hasListener && identical(_keyControllers[key], c)) {
                _keyControllers.remove(key);
                unawaited(c.close());
              }
            },
          );
          return c;
        },
      );
      return controller.stream;
    } else {
      return _streamController.stream;
    }
  }

  /// Not part of public API
  Future<void> close() {
    if (_keyControllers.isEmpty) {
      return _streamController.close();
    }
    final controllers = _keyControllers.values.toList();
    _keyControllers.clear();
    return Future.wait<void>([
      _streamController.close(),
      for (final controller in controllers) controller.close(),
    ]);
  }
}
