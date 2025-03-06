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
    required MessageType type,
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
        case MessageType.managerOpen:
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
        case MessageType.managerDeleteBox:
          final payload = message.payload as ManagerDeleteBoxPayload;
          await backendManager.deleteBox(
            payload.name,
            payload.path,
            payload.collection,
          );
          result = null;
        case MessageType.managerBoxExists:
          final payload = message.payload as ManagerBoxExistsPayload;
          result = await backendManager.boxExists(
            payload.name,
            payload.path,
            payload.collection,
          );
        case MessageType.storageInitialize:
          final payload = message.payload as StorageInitializePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.initialize(
            payload.registry,
            payload.keystore,
            payload.lazy,
          );
          result = null;
        case MessageType.storageReadValue:
          final payload = message.payload as StorageReadValuePayload;
          final backend = storageBackends[payload.storageId]!;
          result = await backend.readValue(payload.frame);
        case MessageType.storageWriteFrames:
          final payload = message.payload as StorageWriteFramesPayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.writeFrames(payload.frames);
          result = null;
        case MessageType.storageCompact:
          final payload = message.payload as StorageCompactPayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.compact(payload.frames);
          result = null;
        case MessageType.storageClear:
          final payload = message.payload as StoragePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.clear();
          result = null;
        case MessageType.storageClose:
          final payload = message.payload as StoragePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.close();
          storageBackends.remove(payload.storageId);
          result = null;
        case MessageType.storageDeleteFromDisk:
          final payload = message.payload as StoragePayload;
          final backend = storageBackends[payload.storageId]!;
          await backend.deleteFromDisk();
          storageBackends.remove(payload.storageId);
          result = null;
        case MessageType.storageFlush:
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
      type: MessageType.managerOpen,
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
      type: MessageType.managerDeleteBox,
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
      type: MessageType.managerBoxExists,
      payload: ManagerBoxExistsPayload(
        name: name,
        path: path,
        collection: collection,
      ),
    );
  }
}
