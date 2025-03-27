import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/connect/hive_connect_api.dart';
import 'package:hive_ce/src/connect/inspectable_box.dart';

/// Handles box inspection through `hive_ce_inspector`
class HiveConnect {
  static const _version = 1;

  static const _handlers =
      <ConnectAction, FutureOr Function(Map<String, dynamic>)>{
    ConnectAction.listBoxes: _listBoxes,
    ConnectAction.getBoxFrames: _getBoxFrames,
    ConnectAction.getValue: _getValue,
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
          final args = parameters.containsKey('args')
              ? jsonDecode(parameters['args']!) as Map<String, dynamic>
              : <String, dynamic>{};
          final result = <String, dynamic>{'result': await handler.value(args)};
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
    final info = await Service.getInfo();
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
    final url = ' https://inspect.hive.isar.community/#/$_version/$port$path ';
    String line(String text, String fill) {
      final fillCount = url.length - text.length;
      final left = List.filled(fillCount ~/ 2, fill);
      final right = List.filled(fillCount - left.length, fill);
      return left.join() + text + right.join();
    }

    print('╔${line('', '═')}╗');
    print('║${line('HIVE CONNECT STARTED', ' ')}║');
    print('╟${line('', '─')}╢');
    print('║${line('Open the link to connect to the Hive', ' ')}║');
    print('║${line('Inspector while this build is running.', ' ')}║');
    print('╟${line('', '─')}╢');
    print('║$url║');
    print('╚${line('', '═')}╝');
  }

  /// Register a box for inspection
  static void registerBox(InspectableBox box) async {
    if (_boxes.containsKey(box.name)) return;
    _initialize();

    _boxes[box.name] = box;

    final frames = await box.getFrames();
    postEvent(
      ConnectEvent.boxRegistered.event,
      {
        'name': box.name,
        'frames': frames
            .map(
              (e) => e.copyWith(value: _writeValue(box.typeRegistry, e.value)),
            )
            .toList(),
      },
    );

    _subscriptions[box.name] = box.watch().listen((event) {
      postEvent(ConnectEvent.boxEvent.event, {
        'name': box.name,
        'key': event.key,
        'value': _writeValue(box.typeRegistry, event.value),
        'deleted': event.deleted,
      });
    });
  }

  /// Remove a box from inspection
  static void unregisterBox(InspectableBox box) {
    _boxes.remove(box.name);
    _subscriptions.remove(box.name)?.cancel();
    postEvent(ConnectEvent.boxUnregistered.event, {'name': box.name});
  }

  static List<String> _listBoxes(_) => _boxes.keys.toList();

  static Future<List<InspectorFrame>> _getBoxFrames(
    Map<String, dynamic> args,
  ) async {
    final name = args['name'] as String;
    final box = _boxes[name];
    if (box == null) return [];

    final frames = await box.getFrames();
    return frames.toList();
  }

  static Future<Object?> _getValue(Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final box = _boxes[name];
    if (box == null) return null;

    final key = args['key'];
    return box.getValue(key);
  }

  static Uint8List _writeValue(TypeRegistry registry, Object? value) {
    if (value is Uint8List) return value;

    final writer = BinaryWriterImpl(registry);
    writer.write(value);
    return writer.toBytes();
  }
}
