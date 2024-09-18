import 'dart:async';

/// Lock mechanism to ensure correct order of execution
class ReadWriteSync {
  Future _readTask = Future.value();

  Future _writeTask = Future.value();

  /// Run operation with read lock
  Future<T> syncRead<T>(Future<T> Function() task) async {
    final previousTask = _readTask;

    final completer = Completer<void>();
    _readTask = completer.future;

    await previousTask;
    try {
      return await task();
    } catch (e) {
      rethrow;
    } finally {
      completer.complete();
    }
  }

  /// Run operation with write lock
  Future<T> syncWrite<T>(Future<T> Function() task) async {
    final previousTask = _writeTask;

    final completer = Completer<void>();
    _writeTask = completer.future;

    await previousTask;
    try {
      return await task();
    } catch (e) {
      rethrow;
    } finally {
      completer.complete();
    }
  }

  /// Run operation with read and write lock
  Future<T> syncReadWrite<T>(FutureOr<T> Function() task) async {
    final previousReadTask = _readTask;
    final previousWriteTask = _writeTask;

    final completer = Completer<void>();
    final future = completer.future;
    _readTask = future;
    _writeTask = future;

    await previousReadTask;
    await previousWriteTask;
    try {
      return await task();
    } catch (e) {
      rethrow;
    } finally {
      completer.complete();
    }
  }
}
