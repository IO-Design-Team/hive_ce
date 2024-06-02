import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

extension IDBRequestExtension on IDBRequest {
  Future<T> asFuture<T extends JSAny?>() {
    final completer = Completer<T>();
    onsuccess = (Event e) {
      completer.complete(result as T);
    }.toJS;
    onerror = (Event e) {
      completer.completeError(error!);
    }.toJS;
    return completer.future;
  }
}

extension IDBObjectStoreExtension on IDBObjectStore {
  Future<Map<JSAny?, JSAny?>> iterate() async {
    final request = openCursor();
    final completer = Completer<void>();
    final items = <JSAny?, JSAny?>{};
    request.onsuccess = (Event e) {
      final cursor = (e.target as IDBRequest).result as IDBCursorWithValue?;
      if (cursor == null) {
        completer.complete();
        return;
      }
      items[cursor.key] = cursor.value;
      cursor.continue_();
    }.toJS;
    request.onerror = (Event e) {
      completer.completeError(request.error!);
    }.toJS;
    await completer.future;
    return items;
  }
}
