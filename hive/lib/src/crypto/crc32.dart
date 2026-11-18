import 'dart:typed_data';

/// Computes the zlib-compatible CRC32 of a valid byte range in [bytes].
///
/// [seed] is the previous checksum as an unsigned 32-bit integer. Return the
/// same checksum as Hive CE's Dart implementation for the [length] bytes
/// starting at [offset], including returning [seed] for an empty range.
/// The callback must treat [bytes] as read-only.
typedef Crc32Accelerator = int Function(
  Uint8List bytes,
  int seed,
  int offset,
  int length,
);

/// Slicing-by-8 CRC32 implementation
class Crc32 {
  static final _tables = _buildTables();

  static List<Uint32List> _buildTables() {
    final tables = List.generate(8, (_) => Uint32List(256));
    final t0 = tables[0];
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
      }
      t0[n] = c;
    }
    for (var n = 0; n < 256; n++) {
      var c = t0[n];
      for (var k = 1; k < 8; k++) {
        c = t0[c & 0xff] ^ (c >> 8);
        tables[k][n] = c;
      }
    }
    return tables;
  }

  /// Optional native CRC32 accelerator installed via `installCrc32Accelerator`.
  static Crc32Accelerator? nativeCompute;

  /// Computes the CRC32 checksum of [bytes] using a previous [crc] value.
  static int compute(
    Uint8List bytes, {
    int crc = 0,
    int offset = 0,
    int? length,
  }) {
    length ??= bytes.length;

    final nativeCompute = Crc32.nativeCompute;
    if (nativeCompute != null && crc >= 0 && crc <= 0xffffffff) {
      return nativeCompute(bytes, crc, offset, length);
    }

    final t0 = _tables[0];
    final t1 = _tables[1];
    final t2 = _tables[2];
    final t3 = _tables[3];
    final t4 = _tables[4];
    final t5 = _tables[5];
    final t6 = _tables[6];
    final t7 = _tables[7];

    crc = crc ^ 0xffffffff;

    var i = offset;
    final end = offset + length;
    // Custom ciphers can return a key CRC outside of 32 bits. Process it one
    // byte at a time so the result matches checksums that are already stored.
    for (; i < end && (crc < 0 || crc > 0xffffffff); i++) {
      crc = t0[(crc ^ bytes[i]) & 0xff] ^ (crc >> 8);
    }
    while (end - i >= 8) {
      final a = crc ^
          (bytes[i] |
              (bytes[i + 1] << 8) |
              (bytes[i + 2] << 16) |
              (bytes[i + 3] << 24));
      crc = t7[a & 0xff] ^
          t6[(a >> 8) & 0xff] ^
          t5[(a >> 16) & 0xff] ^
          t4[a >> 24] ^
          t3[bytes[i + 4]] ^
          t2[bytes[i + 5]] ^
          t1[bytes[i + 6]] ^
          t0[bytes[i + 7]];
      i += 8;
    }
    for (; i < end; i++) {
      crc = t0[(crc ^ bytes[i]) & 0xff] ^ (crc >> 8);
    }

    return crc ^ 0xffffffff;
  }
}
