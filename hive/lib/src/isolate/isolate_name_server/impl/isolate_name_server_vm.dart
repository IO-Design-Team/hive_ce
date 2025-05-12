import 'dart:isolate';

/// An abstraction of the [IsolateNameServer]
abstract class IsolateNameServer {
  /// Constructor
  const IsolateNameServer();

  /// Looks up the [SendPort] associated with a given name
  SendPort? lookupPortByName(String name);

  /// Registers a [SendPort] with a given name
  bool registerPortWithName(SendPort port, String name);

  /// Removes a name-to-[SendPort] mapping given its name
  bool removePortNameMapping(String name);
}
