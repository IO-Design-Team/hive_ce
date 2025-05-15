import 'dart:ui' as flutter;

import 'package:hive_ce_flutter/hive_flutter.dart' as hive;

/// A wrapper around [flutter.IsolateNameServer] for [IsolatedHive]
class IsolateNameServer extends hive.IsolateNameServer {
  /// Constructor
  const IsolateNameServer();

  @override
  dynamic lookupPortByName(String name) =>
      flutter.IsolateNameServer.lookupPortByName(name);

  @override
  bool registerPortWithName(dynamic port, String name) =>
      flutter.IsolateNameServer.registerPortWithName(port, name);

  @override
  bool removePortNameMapping(String name) =>
      flutter.IsolateNameServer.removePortNameMapping(name);
}
