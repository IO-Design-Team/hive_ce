import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

extension IDBRequestExtension on IDBRequest {
  Future<dynamic> asFuture() {
    final completer = Completer<dynamic>();
    onsuccess = (e) {
      completer.complete(result);
    }.toJS;
    onerror = (e) {
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
    cursorRequest.onsuccess = (e) {
      final cursor = e.target.result as IDBCursorWithValue?;
      if (cursor == null) {
        cursorCompleter.complete();
        return;
      }
      cursors.add(cursor);
    }.toJS;
    cursorRequest.onerror = (e) {
      cursorCompleter.completeError(cursorRequest.error!);
    }.toJS;
    await cursorCompleter.future;
    return cursors;
  }
}
