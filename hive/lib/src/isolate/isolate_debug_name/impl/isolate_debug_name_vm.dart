import 'dart:isolate';

/// The debug name of the current isolate
final isolateDebugName = Isolate.current.debugName ?? '';
