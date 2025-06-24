/// An abstraction of the [IsolateNameServer]
abstract class IsolateNameServer {
  /// Constructor
  const IsolateNameServer();

  /// Looks up the [SendPort] associated with a given name
  ///
  /// This returns [dynamic] to maintain web compatibility
  dynamic lookupPortByName(String name);

  /// Registers a [SendPort] with a given name
  ///
  /// This accepts [dynamic] to maintain web compatibility
  bool registerPortWithName(dynamic port, String name);

  /// Removes a name-to-[SendPort] mapping given its name
  bool removePortNameMapping(String name);
}
