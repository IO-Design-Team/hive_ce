import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/keystore.dart';

/// Message types for communication with the isolate
enum IsolateMessageType {
  managerOpen,
  managerDeleteBox,
  managerBoxExists,
  storageInitialize,
  storageReadValue,
  storageWriteFrames,
  storageCompact,
  storageClear,
  storageClose,
  storageDeleteFromDisk,
  storageFlush,
}

/// Base message for communication with the isolate
class IsolateMessage {
  final int id;
  final IsolateMessageType type;
  final Object? payload;

  const IsolateMessage({
    required this.id,
    required this.type,
    required this.payload,
  });
}

/// Message to open a box
class ManagerOpenPayload {
  final String name;
  final String? path;
  final bool crashRecovery;
  final HiveCipher? cipher;
  final String? collection;

  const ManagerOpenPayload({
    required this.name,
    this.path,
    required this.crashRecovery,
    this.cipher,
    this.collection,
  });
}

/// Message to delete a box
class ManagerDeleteBoxPayload {
  final String name;
  final String? path;
  final String? collection;

  const ManagerDeleteBoxPayload({
    required this.name,
    this.path,
    this.collection,
  });
}

/// Message to check if a box exists
class ManagerBoxExistsPayload {
  final String name;
  final String? path;
  final String? collection;

  const ManagerBoxExistsPayload({
    required this.name,
    this.path,
    this.collection,
  });
}

/// Base class for storage messages
class StoragePayload {
  final int storageId;

  const StoragePayload({
    required this.storageId,
  });
}

/// Message to initialize storage
class StorageInitializePayload extends StoragePayload {
  final TypeRegistry registry;
  final Keystore keystore;
  final bool lazy;

  const StorageInitializePayload({
    required super.storageId,
    required this.registry,
    required this.keystore,
    required this.lazy,
  });
}

/// Message to read a value from storage
class StorageReadValuePayload extends StoragePayload {
  final Frame frame;

  const StorageReadValuePayload({
    required super.storageId,
    required this.frame,
  });
}

/// Message to write frames to storage
class StorageWriteFramesPayload extends StoragePayload {
  final List<Frame> frames;

  const StorageWriteFramesPayload({
    required super.storageId,
    required this.frames,
  });
}

/// Message to compact storage
class StorageCompactPayload extends StoragePayload {
  final Iterable<Frame> frames;

  const StorageCompactPayload({
    required super.storageId,
    required this.frames,
  });
}

/// Response from the isolate
class IsolateResponse {
  final int id;
  final Object? payload;

  const IsolateResponse({
    required this.id,
    this.payload
  });
}

/// Storage backend information returned from isolate
class StorageInfoPayload {
  final int id;
  final String? path;
  final bool supportsCompaction;

  const StorageInfoPayload({
    required this.id,
    this.path,
    required this.supportsCompaction,
  });
}
