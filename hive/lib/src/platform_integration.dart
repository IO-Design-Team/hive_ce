/// Hooks for platform packages that integrate with Hive CE.
library;

import 'package:hive_ce/src/crypto/crc32.dart';

export 'package:hive_ce/src/crypto/crc32.dart' show Crc32Accelerator;

/// Installs [accelerator] in the current isolate for unsigned 32-bit seeds.
///
/// The default `IsolatedHive` worker inherits the installed accelerator when
/// it starts. Pass a top-level or static function and install it before
/// initializing `IsolatedHive`. Hive CE handles other seeds in Dart.
void installCrc32Accelerator(Crc32Accelerator accelerator) {
  Crc32.nativeCompute = accelerator;
}
