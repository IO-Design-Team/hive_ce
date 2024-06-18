import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// TODO: Document this!
extension IDBRequestExtension on IDBRequest {
  /// TODO: Document this!
  Future<T> asFuture<T extends JSAny?>() {
    final completer = Completer<T>();
    onsuccess = (e) {
      completer.complete(result as T);
    }.toJS;
    onerror = (e) {
      completer.completeError(error!);
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
    request.onsuccess = (e) {
      final cursor = (e.target as IDBRequest).result as IDBCursorWithValue?;
      if (cursor == null) {
        controller.close();
        return;
      }
      controller.add(cursor);
      cursor.continue_();
    }.toJS;
    request.onerror = (e) {
      controller.addError(request.error!);
    }.toJS;
    return controller.stream;
  }
}
