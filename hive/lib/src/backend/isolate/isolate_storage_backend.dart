import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/backend/isolate/isolate_backend_manager.dart';
import 'package:hive_ce/src/backend/isolate/isolate_messages.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/keystore.dart';

/// A StorageBackend implementation that forwards operations to the real backend in the isolate
class IsolateStorageBackend implements StorageBackend {
  final int id;
  final IsolateBackendManager manager;
  final String? path;
  final bool supportsCompaction;

  const IsolateStorageBackend({
    required this.id,
    required this.manager,
    this.path,
    required this.supportsCompaction,
  });

  @override
  Future<void> initialize(TypeRegistry registry, Keystore keystore, bool lazy) {
    return manager.sendMessage(
      type: MessageType.storageInitialize,
      payload: StorageInitializePayload(
        storageId: id,
        registry: registry,
        keystore: keystore,
        lazy: lazy,
      ),
    );
  }

  @override
  Future<dynamic> readValue(Frame frame) {
    return manager.sendMessage(
      type: MessageType.storageReadValue,
      payload: StorageReadValuePayload(storageId: id, frame: frame),
    );
  }

  @override
  Future<void> writeFrames(List<Frame> frames) {
    return manager.sendMessage(
      type: MessageType.storageWriteFrames,
      payload: StorageWriteFramesPayload(storageId: id, frames: frames),
    );
  }

  @override
  Future<void> compact(Iterable<Frame> frames) {
    return manager.sendMessage(
      type: MessageType.storageCompact,
      payload: StorageCompactPayload(storageId: id, frames: frames),
    );
  }

  @override
  Future<void> clear() {
    return manager.sendMessage(
      type: MessageType.storageClear,
      payload: StoragePayload(storageId: id),
    );
  }

  @override
  Future<void> close() {
    return manager.sendMessage(
      type: MessageType.storageClose,
      payload: StoragePayload(storageId: id),
    );
  }

  @override
  Future<void> deleteFromDisk() {
    return manager.sendMessage(
      type: MessageType.storageDeleteFromDisk,
      payload: StoragePayload(storageId: id),
    );
  }

  @override
  Future<void> flush() {
    return manager.sendMessage(
      type: MessageType.storageFlush,
      payload: StoragePayload(storageId: id),
    );
  }
}
