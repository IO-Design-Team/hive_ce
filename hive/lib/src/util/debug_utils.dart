/// Returns true if assertions are enabled
final kDebugMode = () {
  bool? assertionsEnabled;
  assert(assertionsEnabled = true);
  return assertionsEnabled ?? false;
}();

/// Only print the given message if assertions are enabled
void debugPrint(String message) => kDebugMode ? print(message) : null;
