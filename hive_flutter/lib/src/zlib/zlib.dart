import 'dart:ffi';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

@Native<UnsignedLong Function(UnsignedLong, Pointer<Uint8>, UnsignedInt)>(
  symbol: 'crc32',
  isLeaf: true,
)
external int _crc32(int crc, Pointer<Uint8> buf, int len);

int _compute(Uint8List bytes, int crc, int offset, int length) => _crc32(
  crc,
  Uint8List.sublistView(bytes, offset, offset + length).address,
  length,
);

/// Computes Hive checksums with zlib if it is available
void useZlibCrc32() {
  try {
    _crc32(0, nullptr, 0);
  } on ArgumentError {
    return;
  }
  installCrc32Accelerator(_compute);
}
