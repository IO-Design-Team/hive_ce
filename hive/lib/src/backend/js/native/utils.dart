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
