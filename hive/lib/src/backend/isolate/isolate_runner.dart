import 'dart:async';
import 'dart:isolate';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/isolate/isolate_messages.dart';

/// Type definition for an isolate entry point function
typedef EntryPoint = void Function(SendPort);

/// Manages communication with an isolate
class IsolateRunner {
  late final SendPort _sendPort;
  late final Isolate _isolate;
  final Completer<void> _initCompleter = Completer<void>();
  final Map<int, Completer<Object?>> _pendingRequests = {};
  int _nextId = 0;

  /// Whether the isolate is initialized
  Future<void> get isInitialized => _initCompleter.future;

  /// Creates a new IsolateRunner and initializes the worker isolate
  IsolateRunner(EntryPoint entryPoint) {
    _initIsolate(entryPoint);
  }

  void _initIsolate(EntryPoint entryPoint) async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(entryPoint, receivePort.sendPort);

    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _initCompleter.complete();
      } else if (message is IsolateResponse) {
        final completer = _pendingRequests.remove(message.id);
        completer?.complete(message.payload);
      }
    });
  }

  /// Sends a message to the isolate and returns a future that completes with the response
  Future<T> sendMessage<T>({
    required IsolateMessageType type,
    Object? payload,
  }) async {
    await isInitialized;

    final id = _nextId++;
    final completer = Completer<T>();
    _pendingRequests[id] = completer;

    _sendPort.send(IsolateMessage(id: id, type: type, payload: payload));

    return completer.future;
  }

  /// Closes the isolate and cleans up resources
  Future<void> close() async {
    if (!_initCompleter.isCompleted) return;
    _isolate.kill();
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(HiveError('Isolate was closed'));
      }
    }
    _pendingRequests.clear();
  }
}
