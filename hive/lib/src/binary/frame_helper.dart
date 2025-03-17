import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/box/keystore.dart';

/// Not part of public API
class FrameHelper {
  /// Not part of public API
  int framesFromBytes(
    Uint8List bytes,
    Keystore? keystore,
    TypeRegistry registry,
    HiveCipher? cipher, {
    bool verbatim = false,
  }) {
    final reader = BinaryReaderImpl(bytes, registry);

    while (reader.availableBytes != 0) {
      final frameOffset = reader.usedBytes;

      final frame = reader.readFrame(
        cipher: cipher,
        lazy: false,
        frameOffset: frameOffset,
        verbatim: verbatim,
      );
      if (frame == null) return frameOffset;

      keystore!.insert(frame, notify: false);
    }

    return -1;
  }
}
