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
      final err = error;
      if (err == null) {
        completer.completeError(StateError('IDBRequest failed without an error'));
      } else {
        completer.completeError(err);
      }
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
      final err = request.error;
      if (err == null) {
        controller.addError(StateError('IDBRequest failed without an error'));
      } else {
        controller.addError(err);
      }
    }.toJS;
    return controller.stream;
  }
}
