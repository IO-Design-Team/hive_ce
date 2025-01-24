/// Only run the given function if assertions are enabled
void ifDebug(void Function() f) {
  assert(() {
    f();
    return true;
  }());
}

/// Only print the given message if assertions are enabled
void debugPrint(Object? object) => ifDebug(() => print(object));
