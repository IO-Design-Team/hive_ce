import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// TODO: Document this!
extension IDBRequestExtension on IDBRequest {
  /// TODO: Document this!
  Future<T> asFuture<T extends JSAny?>() {
    final completer = Completer<T>();
    // ignore: avoid_types_on_closure_parameters
    onsuccess = (Event e) {
      completer.complete(result as T);
    }.toJS;
    // ignore: avoid_types_on_closure_parameters
    onerror = (Event e) {
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
    // ignore: avoid_types_on_closure_parameters
    request.onsuccess = (Event e) {
      final cursor = (e.target as IDBRequest).result as IDBCursorWithValue?;
      if (cursor == null) {
        controller.close();
        return;
      }
      controller.add(cursor);
      cursor.continue_();
    }.toJS;
    // ignore: avoid_types_on_closure_parameters
    request.onerror = (Event e) {
      controller.addError(request.error!);
    }.toJS;
    return controller.stream;
  }
}
