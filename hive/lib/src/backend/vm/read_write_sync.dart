import 'dart:async';

/// Lock mechanism to ensure correct order of execution
class ReadWriteSync {
  Future _readTask = Future.value();

  Future _writeTask = Future.value();

  /// Run operation with read lock
  Future<T> syncRead<T>(Future<T> Function() task) {
    final previousTask = _readTask;

    final completer = Completer();
    _readTask = completer.future;

    return previousTask.then((_) => task()).whenComplete(completer.complete);
  }

  /// Run operation with write lock
  Future<T> syncWrite<T>(Future<T> Function() task) {
    final previousTask = _writeTask;

    final completer = Completer();
    _writeTask = completer.future;

    return previousTask.then((_) => task()).whenComplete(completer.complete);
  }

  /// Run operation with read and write lock
  Future<T> syncReadWrite<T>(FutureOr<T> Function() task) {
    final previousReadTask = _readTask;
    final previousWriteTask = _writeTask;

    final completer = Completer();
    final future = completer.future;
    _readTask = future;
    _writeTask = future;

    return previousReadTask.then((_) {
      return previousWriteTask.then((_) => task());
    }).whenComplete(completer.complete);
  }
}
