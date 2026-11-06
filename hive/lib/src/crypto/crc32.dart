import 'dart:typed_data';

/// Efficient CRC32 implementation (IEEE, reflected polynomial 0xEDB88320).
///
/// Uses slicing-by-8: eight lookup tables let the loop consume eight bytes
/// per iteration instead of one. The result is identical to the classic
/// byte-at-a-time table implementation.
class Crc32 {
  static final List<Uint32List> _tables = _buildTables();

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

  /// Computes the CRC32 checksum of [bytes] using a previous [crc] value.
  static int compute(
    Uint8List bytes, {
    int crc = 0,
    int offset = 0,
    int? length,
  }) {
    final tables = _tables;
    final t0 = tables[0];
    final t1 = tables[1];
    final t2 = tables[2];
    final t3 = tables[3];
    final t4 = tables[4];
    final t5 = tables[5];
    final t6 = tables[6];
    final t7 = tables[7];

    crc = (crc ^ 0xffffffff) & 0xffffffff;

    length ??= bytes.length;

    var i = offset;
    final end = offset + length;
    while (end - i >= 8) {
      final a = crc ^
          (bytes[i] |
              (bytes[i + 1] << 8) |
              (bytes[i + 2] << 16) |
              (bytes[i + 3] << 24));
      crc = t7[a & 0xff] ^
          t6[(a >> 8) & 0xff] ^
          t5[(a >> 16) & 0xff] ^
          t4[(a >> 24) & 0xff] ^
          t3[bytes[i + 4]] ^
          t2[bytes[i + 5]] ^
          t1[bytes[i + 6]] ^
          t0[bytes[i + 7]];
      i += 8;
    }
    while (i < end) {
      crc = t0[(crc ^ bytes[i]) & 0xff] ^ (crc >> 8);
      i++;
    }

    return crc ^ 0xffffffff;
  }
}
