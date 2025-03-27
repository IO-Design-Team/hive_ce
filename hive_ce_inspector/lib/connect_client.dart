// This is internal access
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/connect/hive_connect_api.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ConnectClient {
  final VmService vmService;
  final String isolateId;

  ConnectClient(this.vmService, this.isolateId);

  static Future<ConnectClient> connect(String port, String secret) async {
    final wsUrl = Uri.parse('ws://127.0.0.1:$port/$secret=/ws');
    final channel = WebSocketChannel.connect(wsUrl);

    // Ignore
    // ignore: avoid_print
    final stream = channel.stream.handleError(print);

    final service = VmService(
      stream,
      channel.sink.add,
      disposeHandler: channel.sink.close,
    );
    final vm = await service.getVM();
    final isolateId = vm.isolates!.where((e) => e.name == 'main').first.id!;
    await service.streamListen(EventStreams.kExtension);

    final client = ConnectClient(service, isolateId);
    final handlers = <String, Function(Map<String, dynamic>)>{
      ConnectEvent.boxRegistered.event: (Map<String, dynamic> json) {
        client._boxRegisteredController.add(json['name']);
      },
      ConnectEvent.boxUnregistered.event: (Map<String, dynamic> json) {
        client._boxUnregisteredController.add(json['name']);
      },
      ConnectEvent.boxEvent.event: (Map<String, dynamic> json) {
        client._boxEventController.add(BoxEventPayload.fromJson(json));
      },
    };
    service.onExtensionEvent.listen((event) {
      final data = event.extensionData?.data ?? {};
      handlers[event.extensionKind]?.call(data);
    });

    return client;
  }

  final _boxRegisteredController = StreamController<String>.broadcast();
  final _boxUnregisteredController = StreamController<String>.broadcast();
  final _boxEventController = StreamController<BoxEventPayload>.broadcast();

  Stream<String> get boxRegistered => _boxRegisteredController.stream;
  Stream<String> get boxUnregistered => _boxUnregisteredController.stream;
  Stream<BoxEventPayload> get boxEvent => _boxEventController.stream;

  Future<Object?> _call(ConnectAction action, {dynamic param}) async {
    final response = await vmService.callServiceExtension(
      action.method,
      isolateId: isolateId,
      args: {if (param != null) 'args': jsonEncode(param)},
    );

    return response.json?['result'] as Object?;
  }

  Future<List<String>> listBoxes() async {
    final response = await _call(ConnectAction.listBoxes);
    if (response == null) return [];

    return (response as List).cast<String>();
  }

  Future<List<InspectorFrame>> getBoxFrames(String name) async {
    final response = await _call(ConnectAction.getBoxFrames, param: name);
    if (response == null) return [];

    return (response as List).map((e) => InspectorFrame.fromJson(e)).map((e) {
      if (e.lazy) return e;
      return e.copyWith(
        value:
            BinaryReaderImpl(
              e.value as Uint8List,
              StubRegistry(),
            ).readAsObject(),
      );
    }).toList();
  }

  Future<Object?> getValue(String name, String key) async {
    final value = await _call(
      ConnectAction.getValue,
      param: {'name': name, 'key': key},
    );
    if (value == null) return null;

    return BinaryReaderImpl(value as Uint8List, StubRegistry()).readAsObject();
  }
}

class StubRegistry extends TypeRegistry {
  @override
  void ignoreTypeId<T>(int typeId) => throw UnimplementedError();

  @override
  bool isAdapterRegistered(int typeId) => throw UnimplementedError();

  @override
  void registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) => throw UnimplementedError();
}
