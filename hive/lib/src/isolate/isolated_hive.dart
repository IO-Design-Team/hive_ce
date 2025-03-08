import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

class IsolatedHive implements HiveInterface {
  late final IsolateMethodChannel _channel;

  /// Must only be called once per isolate
  ///
  /// If accessing Hive in multiple isolates, an [isolateNameSever] MUST be
  /// passed to avoid box corruption
  @override
  Future<void> init(
    String? path, {
    // Unused
    HiveStorageBackendPreference? backendPreference,
    // TODO: Implement this
    Object? isolateNameServer,
  }) async {
    final (send, receive, shutdown) = await spawnIsolate(_isolateEntryPoint);
    _channel = IsolateMethodChannel('hive', send, receive);
    return _channel.invokeMethod('init', path);
  }

  @override
  Future<IsolatedBox<E>> openBox<E>(
    String name, {
    // TODO: Implement these fields
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    Uint8List? bytes,
    String? collection,
    List<int>? encryptionKey,
  }) async {
    await _channel.invokeMethod('openBox', name);
    return IsolatedBox(_channel, name);
  }

  @override
  Box<E> box<E>(String name) => IsolatedBox(_channel, name);

  @override
  Future<bool> boxExists(String name, {String? path}) {
    // TODO: implement boxExists
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) {
    // TODO: implement deleteBoxFromDisk
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFromDisk() {
    // TODO: implement deleteFromDisk
    throw UnimplementedError();
  }

  @override
  List<int> generateSecureKey() {
    // TODO: implement generateSecureKey
    throw UnimplementedError();
  }

  @override
  void ignoreTypeId<T>(int typeId) {
    // TODO: implement ignoreTypeId
  }

  @override
  bool isAdapterRegistered(int typeId) {
    // TODO: implement isAdapterRegistered
    throw UnimplementedError();
  }

  @override
  bool isBoxOpen(String name) {
    // TODO: implement isBoxOpen
    throw UnimplementedError();
  }

  @override
  LazyBox<E> lazyBox<E>(String name) {
    // TODO: implement lazyBox
    throw UnimplementedError();
  }

  @override
  Future<LazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
    List<int>? encryptionKey,
  }) {
    // TODO: implement openLazyBox
    throw UnimplementedError();
  }

  @override
  void registerAdapter<T>(TypeAdapter<T> adapter,
      {bool internal = false, bool override = false}) {
    // TODO: implement registerAdapter
  }

  @override
  void resetAdapters() {
    // TODO: implement resetAdapters
  }
}

void _isolateEntryPoint(SendPort send) {
  final receive = setupIsolate(send);
  final channel = IsolateMethodChannel('hive', send, receive);

  channel.setMethodCallHandler(_handleMethodCall);
}

void _handleMethodCall(IsolateMethodCall call, IsolateResult result) async {
  switch (call.method) {
    case 'init':
      Hive.init(call.arguments);
      result(null);
    case 'openBox':
      await Hive.openBox(call.arguments);
      result(null);
    case 'put':
      await Hive.box(call.arguments[0]).put(call.arguments[1], call.arguments[2]);
      result(null);
  }
}
