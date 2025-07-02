import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/raw_object_writer.dart';
import 'package:hive_ce/src/connect/hive_connect_api.dart';
import 'package:hive_ce/src/connect/inspectable_box.dart';

/// Handles box inspection through `hive_ce_inspector`
class HiveConnect {
  static const _version = 1;
  static const _baseUrl = 'https://inspect.hive.isar.community';

  static const _handlers = <ConnectAction, FutureOr Function(dynamic)>{
    ConnectAction.listBoxes: _listBoxes,
    ConnectAction.getBoxFrames: _getBoxFrames,
    ConnectAction.loadValue: _loadValue,
  };

  const HiveConnect._();

  static final _boxes = <String, InspectableBox>{};
  static final _subscriptions = <String, StreamSubscription>{};

  static var _initialized = false;

  static void _initialize() {
    if (_initialized) return;

    _registerHandlers();
    _printConnection();

    _initialized = true;
  }

  static void _registerHandlers() {
    for (final handler in _handlers.entries) {
      registerExtension(handler.key.method, (method, parameters) async {
        try {
          final args = parameters['args'];
          final result = <String, dynamic>{
            'result':
                await handler.value(args == null ? null : jsonDecode(args)),
          };
          return ServiceExtensionResponse.result(jsonEncode(result));
        } catch (e) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.extensionError,
            e.toString(),
          );
        }
      });
    }
  }

  static void _printConnection() async {
    final ServiceProtocolInfo info;
    try {
      info = await Service.getInfo();
    } catch (_) {
      _printUrl('$_baseUrl/$_version/');
      return;
    }

    final serviceUri = info.serverUri;
    if (serviceUri == null) return;

    final port = serviceUri.port;
    var path = serviceUri.path;
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.endsWith('=')) {
      path = path.substring(0, path.length - 1);
    }

    _printUrl('$_baseUrl/$_version/$port$path');
  }

  static void _printUrl(String url) {
    String line(String text, String fill) {
      final fillCount = url.length - text.length + 2;
      final left = List.filled(fillCount ~/ 2, fill);
      final right = List.filled(fillCount - left.length, fill);
      return left.join() + text + right.join();
    }

    print('╔${line('', '═')}╗');
    print('║${line('HIVE CE CONNECT STARTED', ' ')}║');
    print('╟${line('', '─')}╢');
    print('║${line('Open the link to connect to the Hive', ' ')}║');
    print('║${line('Inspector while this build is running.', ' ')}║');
    print('╟${line('', '─')}╢');
    print('║ $url ║');
    print('╚${line('', '═')}╝');
  }

  /// Register a box for inspection
  static void registerBox(InspectableBox box) {
    if (_boxes.containsKey(box.name)) return;
    _initialize();

    _boxes[box.name] = box;
    postEvent(ConnectEvent.boxRegistered.event, {'name': box.name});

    _subscriptions[box.name] = box.watch().listen((event) {
      postEvent(
        ConnectEvent.boxEvent.event,
        BoxEventPayload(
          box: box.name,
          frame: InspectorFrame(
            key: event.key,
            value: _writeValue(box.typeRegistry, event.value),
            deleted: event.deleted,
          ),
        ).toJson(),
      );
    });
  }

  /// Remove a box from inspection
  static void unregisterBox(InspectableBox box) {
    _boxes.remove(box.name);
    _subscriptions.remove(box.name)?.cancel();
    postEvent(ConnectEvent.boxUnregistered.event, {'name': box.name});
  }

  static List<String> _listBoxes(dynamic args) => _boxes.keys.toList();

  static Future<List<InspectorFrame>> _getBoxFrames(dynamic args) async {
    final name = args['name'] as String;
    final box = _boxes[name];
    if (box == null) return [];

    final frames = await box.getFrames();
    return frames
        .map((e) => e.copyWith(value: _writeValue(box.typeRegistry, e.value)))
        .toList();
  }

  static Future<Object?> _loadValue(dynamic args) async {
    final name = args['name'] as String;
    final box = _boxes[name];
    if (box == null) return null;

    final key = args['key'];
    final value = await box.loadValue(key);
    return _writeValue(box.typeRegistry, value);
  }

  static Uint8List _writeValue(TypeRegistry registry, Object? value) {
    final writer = RawObjectWriter(registry);
    writer.write(value);
    return writer.toBytes();
  }
}
