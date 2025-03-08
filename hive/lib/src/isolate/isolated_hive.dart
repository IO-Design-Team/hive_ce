import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

class IsolatedHive implements HiveInterface {
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

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
    _hiveChannel = IsolateMethodChannel('hive', send, receive);
    _boxChannel = IsolateMethodChannel('box', send, receive);
    return _hiveChannel.invokeMethod('init', path);
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
    await _hiveChannel.invokeMethod('openBox', name);
    return IsolatedBox(_boxChannel, name);
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
  Box<E> box<E>(String name) => IsolatedBox(_hiveChannel, name);

  @override
  LazyBox<E> lazyBox<E>(String name) {
    // TODO: implement lazyBox
    throw UnimplementedError();
  }

  @override
  bool isBoxOpen(String name) {
    // TODO: implement isBoxOpen
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
  Future<bool> boxExists(String name, {String? path}) {
    // TODO: implement boxExists
    throw UnimplementedError();
  }

  @override
  void resetAdapters() {
    // TODO: implement resetAdapters
  }

  @override
  void registerAdapter<T>(TypeAdapter<T> adapter,
      {bool internal = false, bool override = false}) {
    // TODO: implement registerAdapter
  }

  @override
  bool isAdapterRegistered(int typeId) {
    // TODO: implement isAdapterRegistered
    throw UnimplementedError();
  }

  @override
  void ignoreTypeId<T>(int typeId) {
    // TODO: implement ignoreTypeId
  }
}

void _isolateEntryPoint(SendPort send) {
  final receive = setupIsolate(send);
  final hiveChannel = IsolateMethodChannel('hive', send, receive);
  final boxChannel = IsolateMethodChannel('box', send, receive);

  hiveChannel.setMethodCallHandler(_handleMethodCall);
  boxChannel.setMethodCallHandler(_handleBoxMethodCall);
}

void _handleMethodCall(IsolateMethodCall call, IsolateResult result) async {
  switch (call.method) {
    case 'init':
      Hive.init(call.arguments);
      result(null);
    case 'openBox':
      await Hive.openBox(call.arguments);
      result(null);
  }
}

void _handleBoxMethodCall(IsolateMethodCall call, IsolateResult result) async {
  switch (call.method) {
    case 'put':
      await Hive.box(call.arguments['name'])
          .put(call.arguments['key'], call.arguments['value']);
      result(null);
  }
}
