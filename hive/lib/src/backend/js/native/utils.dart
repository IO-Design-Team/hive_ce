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
  /// completes with an error if the transaction errors or aborts.
  Future<void> asFuture() {
    final completer = Completer<void>();
    oncomplete = (Event e) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }.toJS;
    onerror = (Event e) {
      if (!completer.isCompleted) {
        final target = e.target;
        final requestError =
            target.isA<IDBRequest>() ? (target as IDBRequest).error : null;
        completer.completeError(
          error ??
              requestError ??
              StateError('IDBTransaction failed without an error'),
        );
      }
    }.toJS;
    onabort = (Event e) {
      if (!completer.isCompleted) {
        completer.completeError(
          error ?? StateError('IDBTransaction aborted without an error'),
        );
      }
    }.toJS;
    return completer.future;
  }
}
