import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

extension IDBRequestExtension on IDBRequest {
  Future<JSAny?> asFuture() {
    final completer = Completer<JSAny?>();
    onsuccess = (Event e) {
      completer.complete(result);
    }.toJS;
    onerror = (Event e) {
      completer.completeError(error!);
    }.toJS;
    return completer.future;
  }
}

extension IDBObjectStoreExtension on IDBObjectStore {
  Future<List<IDBCursorWithValue>> getCursors() async {
    final cursorRequest = openCursor();
    final cursorCompleter = Completer<void>();
    final cursors = <IDBCursorWithValue>[];
    cursorRequest.onsuccess = (Event e) {
      final cursor = (e.target as IDBRequest).result as IDBCursorWithValue?;
      if (cursor == null) {
        cursorCompleter.complete();
        return;
      }
      cursors.add(cursor);
    }.toJS;
    cursorRequest.onerror = (Event e) {
      cursorCompleter.completeError(cursorRequest.error!);
    }.toJS;
    await cursorCompleter.future;
    return cursors;
  }
}
