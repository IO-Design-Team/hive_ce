import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce_inspector/model/hive_internal.dart';
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
        final payload = BoxEventPayload.fromJson(json);
        client._boxEventController.add(
          payload.copyWith(
            frame: payload.frame.copyWith(
              value: client._readValue(payload.frame.value),
            ),
          ),
        );
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

    return (response as List).cast<String>().toList();
  }

  Future<List<InspectorFrame>> getBoxFrames(String name) async {
    final response = await _call(
      ConnectAction.getBoxFrames,
      param: {'name': name},
    );
    if (response == null) return [];

    return (response as List).map((e) => InspectorFrame.fromJson(e)).map((
      frame,
    ) {
      if (frame.lazy) return frame;
      return frame.copyWith(value: _readValue(frame.value));
    }).toList();
  }

  Future<Object?> getValue(String name, String key) async {
    final value = await _call(
      ConnectAction.getValue,
      param: {'name': name, 'key': key},
    );
    if (value == null) return null;

    return _readValue(value);
  }

  Object? _readValue(Object? value) {
    if (value == null) return null;

    return RawObjectReader(
      Uint8List.fromList((value as List).cast<int>()),
      TypeRegistryImpl(),
    ).read();
  }
}
