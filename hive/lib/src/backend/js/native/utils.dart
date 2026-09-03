import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// TODO: Document this!
extension IDBRequestExtension on IDBRequest {
  /// TODO: Document this!
  Future<T> asFuture<T extends JSAny?>({Duration? timeout}) {
    final completer = Completer<T>();
    Timer? timer;

    void dispose() {
      timer?.cancel();
      onsuccess = null;
      onerror = null;
      if (this case final IDBOpenDBRequest openRequest) {
        openRequest.onblocked = null;
      }
    }

    onsuccess = (Event e) {
      dispose();
      completer.complete(result as T);
    }.toJS;

    onerror = (Event e) {
      dispose();
      completer.completeError(error!);
    }.toJS;

    if (this case final IDBOpenDBRequest openRequest) {
      openRequest.onblocked = (Event e) {
        dispose();
        completer.completeError(
          StateError(
              'IndexedDB request blocked: another connection holds the database open.'),
        );
      }.toJS;
    }

    // Hard safety timeout: if IndexedDB never fires success/error/blocked
    // (observed in Firefox privacy mode and some Safari configurations),
    // resolve with an error so the caller can continue instead of hanging.
    timer = Timer(timeout ?? const Duration(seconds: 30), () {
      dispose();
      completer.completeError(
        TimeoutException(
            'IndexedDB request timed out after ${timeout ?? const Duration(seconds: 30)}'),
      );
    });

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
      controller.addError(request.error!);
    }.toJS;
    return controller.stream;
  }
}
