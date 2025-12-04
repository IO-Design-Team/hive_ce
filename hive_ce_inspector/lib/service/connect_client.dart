import 'dart:async';
import 'dart:convert';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:dtd/dtd.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:hive_ce_inspector/service/dtd_extension.dart';
import 'package:hive_ce_inspector/util/base_schema.dart';
import 'package:vm_service/vm_service.dart';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

@immutable
class ConnectClient {
  final VmService vmService;
  final String isolateId;
  final Map<String, HiveSchemaType> types;

  ConnectClient(this.vmService, this.isolateId, this.types);

  static Future<ConnectClient> connect() async {
    final service = serviceManager.service;
    if (service == null) throw 'VM service not found';

    final vm = await service.getVM();
    final isolateId = vm.isolates
        ?.where((e) => e.name?.contains('main') ?? false)
        .first
        .id;

    if (isolateId == null) throw 'Main isolate not found';

    try {
      await service.streamListen(EventStreams.kExtension);
    } catch (_) {
      // Throws if the stream is already listened to
    }

    final dtd = dtdManager.connection.value;
    if (dtd == null) throw 'DTD not found';

    final rootsResponse = await dtdManager.projectRoots();
    if (rootsResponse == null) throw 'Workspace roots not found';

    final uris = <Uri>[];
    for (final root in rootsResponse.uris ?? <Uri>[]) {
      final contents = await dtd
          .listDirectoryContentsRecursive(root.resolve('lib'))
          .toList();
      uris.addAll(contents);
    }

    final appPackageRoot = await serviceManager.connectedAppPackageRoot(
      dtdManager,
    );
    if (appPackageRoot == null) throw 'App package root not found';

    final hiveSchemasUris = uris
        .where((e) => e.path.endsWith('hive_adapters.g.yaml'))
        .toList();

    final appSchemas = <HiveSchema>[];
    final otherSchemas = <HiveSchema>[];
    for (final uri in hiveSchemasUris) {
      final contentResponse = await dtd.readFileAsString(uri);
      final content = contentResponse.content;
      if (content == null) continue;

      final schema = HiveSchema.fromJson(
        jsonDecode(jsonEncode(loadYaml(content))),
      );
      if (uri.path.startsWith(appPackageRoot.path)) {
        appSchemas.add(schema);
      } else {
        otherSchemas.add(schema);
      }
    }

    final types = {
      ...baseSchema,
      for (final schema in otherSchemas) ...schema.types,
      // Schemas for the currently running app take precedence
      for (final schema in appSchemas) ...schema.types,
    };

    final client = ConnectClient(service, isolateId, types);
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
      return frame.copyWith(value: _readValue(frame.value));
    }).toList();
  }

  Future<void> loadValue(String name, InspectorFrame frame) async {
    final value = await _call(
      ConnectAction.loadValue,
      param: {'name': name, 'key': frame.key},
    );
    if (value == null) return;

    _boxEventController.add(
      BoxEventPayload(
        box: name,
        frame: frame.copyWith(value: _readValue(value), lazy: false),
      ),
    );
  }

  Object? _readValue(Object? value) {
    if (value == null) return null;

    return RawObjectReader(
      types,
      Uint8List.fromList((value as List).cast<int>()),
    ).read();
  }
}
