import 'dart:isolate';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend.dart' hide BackendManager;
import 'package:hive_ce/src/backend/vm/backend_manager.dart';
import 'package:hive_ce/src/backend/isolate/isolate_messages.dart';
import 'package:hive_ce/src/backend/isolate/isolate_runner.dart';
import 'package:hive_ce/src/backend/isolate/isolate_storage_backend.dart';

/// A BackendManager implementation that runs operations in a separate isolate
class IsolateBackendManager implements BackendManagerInterface {
  final _isolateRunner = IsolateRunner(_isolateEntryPoint);

  Future<T> sendMessage<T>({
    required IsolateMessageType type,
    Object? payload,
  }) {
    return _isolateRunner.sendMessage<T>(type: type, payload: payload);
  }

  /// Entry point for the isolate
  static void _isolateEntryPoint(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final backendManager = BackendManager();
    final storageBackends = <int, StorageBackend>{};
    var nextStorageId = 0;

    receivePort.listen((message) async {
      if (message is! IsolateMessage) return;

      final Object? result;
      switch (message.type) {
        case IsolateMessageType.managerOpen:
          final payload = message.payload as ManagerOpenPayload;
          final backend = await backendManager.open(
            payload.name,
            payload.path,
            payload.crashRecovery,
            payload.cipher,
            payload.collection,
          );
          final storageId = nextStorageId++;
          storageBackends[storageId] = backend;
          result = StorageInfoPayload(
            id: storageId,
            path: backend.path,
            supportsCompaction: backend.supportsCompaction,
          );
        case IsolateMessageType.managerDeleteBox:
          final payload = message.payload as ManagerDeleteBoxPayload;
          await backendManager.deleteBox(
            payload.name,
            payload.path,
            payload.collection,
          );
          result = null;
        case IsolateMessageType.managerBoxExists:
          final payload = message.payload as ManagerBoxExistsPayload;
          result = await backendManager.boxExists(
            payload.name,
            payload.path,
            payload.collection,
          );
        case IsolateMessageType.storageInitialize:
          final payload = message.payload as StorageInitializePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.initialize(
            payload.registry,
            payload.keystore,
            payload.lazy,
          );
          result = null;
        case IsolateMessageType.storageReadValue:
          final payload = message.payload as StorageReadValuePayload;
          final backend = storageBackends[payload.storageId]!;
          result = await backend.readValue(payload.frame);
        case IsolateMessageType.storageWriteFrames:
          final payload = message.payload as StorageWriteFramesPayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.writeFrames(payload.frames);
          result = null;
        case IsolateMessageType.storageCompact:
          final payload = message.payload as StorageCompactPayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.compact(payload.frames);
          result = null;
        case IsolateMessageType.storageClear:
          final payload = message.payload as StoragePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.clear();
          result = null;
        case IsolateMessageType.storageClose:
          final payload = message.payload as StoragePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.close();
          storageBackends.remove(payload.storageId);
          result = null;
        case IsolateMessageType.storageDeleteFromDisk:
          final payload = message.payload as StoragePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.deleteFromDisk();
          storageBackends.remove(payload.storageId);
          result = null;
        case IsolateMessageType.storageFlush:
          final payload = message.payload as StoragePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.flush();
          result = null;
      }

      sendPort.send(IsolateResponse(id: message.id, payload: result));
    });
  }

  @override
  Future<StorageBackend> open(
    String name,
    String? path,
    bool crashRecovery,
    HiveCipher? cipher,
    String? collection,
  ) async {
    final info = await sendMessage<StorageInfoPayload>(
      type: IsolateMessageType.managerOpen,
      payload: ManagerOpenPayload(
        name: name,
        path: path,
        crashRecovery: crashRecovery,
        cipher: cipher,
        collection: collection,
      ),
    );

    final backend = IsolateStorageBackend(
      id: info.id,
      manager: this,
      path: info.path,
      supportsCompaction: info.supportsCompaction,
    );

    return backend;
  }

  @override
  Future<void> deleteBox(String name, String? path, String? collection) {
    return sendMessage<void>(
      type: IsolateMessageType.managerDeleteBox,
      payload: ManagerDeleteBoxPayload(
        name: name,
        path: path,
        collection: collection,
      ),
    );
  }

  @override
  Future<bool> boxExists(String name, String? path, String? collection) {
    return sendMessage<bool>(
      type: IsolateMessageType.managerBoxExists,
      payload: ManagerBoxExistsPayload(
        name: name,
        path: path,
        collection: collection,
      ),
    );
  }
}
