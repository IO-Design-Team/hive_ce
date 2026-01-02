/// Returns true if assertions are enabled
final kDebugMode = () {
  bool? assertionsEnabled;
  assert(assertionsEnabled = true);
  return assertionsEnabled ?? false;
}();
