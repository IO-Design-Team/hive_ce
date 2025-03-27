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
