/// Box inspection actions
enum ConnectAction {
  /// List all boxes currently set up for inspection
  listBoxes,

  /// Get all frames for a given box
  getBoxFrames,

  /// Read the value of a given key
  getValue;

  /// The method name
  String get method => 'ext.hive_ce.$name';
}

/// Box inspection events
enum ConnectEvent {
  /// A box was added for inspection
  boxRegistered,

  /// A box was removed from inspection
  boxUnregistered,

  /// A box event occurred
  boxEvent;

  /// The event name
  String get event => 'ext.hive_ce.$name';
}
