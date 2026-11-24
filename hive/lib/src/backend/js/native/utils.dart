import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// TODO: Document this!
extension IDBRequestExtension on IDBRequest {
  /// TODO: Document this!
  Future<T> asFuture<T extends JSAny?>() {
    final completer = Completer<T>();
    onsuccess = (Event e) {
      completer.complete(result as T);
    }.toJS;
    onerror = (Event e) {
      completer.completeError(
        error ?? StateError('IDBRequest failed without an error'),
      );
    }.toJS;
    return completer.future;
  }
}

/// TODO: Document this!
extension IDBObjectStoreExtension on IDBObjectStore {
  /// TODO: Document this!
  Stream<IDBCursorWithValue> iterate() {
    final controller = StreamController<IDBCursorWithValue>();
    final request = openCursor();
    request.onsuccess = (Event e) {
      final cursor = (e.target as IDBRequest).result as IDBCursorWithValue?;
      if (cursor == null) {
        controller.close();
        return;
      }
      controller.add(cursor);
      cursor.continue_();
    }.toJS;
    request.onerror = (Event e) {
      controller.addError(
        request.error ?? StateError('IDBRequest failed without an error'),
      );
    }.toJS;
    return controller.stream;
  }
}

/// Extensions for [IDBTransaction]
extension IDBTransactionExtension on IDBTransaction {
  /// Returns a [Future] that completes when this transaction completes, or
  /// completes with an error if the transaction aborts.
  Future<void> asFuture() {
    final completer = Completer<void>();
    oncomplete = (Event e) {
      completer.complete();
    }.toJS;
    onabort = (Event e) {
      completer.completeError(
        error ?? StateError('IDBTransaction aborted without an error'),
      );
    }.toJS;
    return completer.future;
  }

  /// Executes [action] synchronously within this transaction, aborting the
  /// transaction if [action] throws, and awaits transaction completion.
  Future<void> run(void Function() action) async {
    try {
      action();
    } on Object {
      try {
        abort();
      } on Object {
        // Keep the original error if aborting fails.
      }
      rethrow;
    }
    await asFuture();
  }
}
