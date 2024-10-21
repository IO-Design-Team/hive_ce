import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

class HiveCipherImpl extends HiveCipher {
  @override
  int calculateKeyCrc() => throw UnimplementedError();

  @override
  int decrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) =>
      throw UnimplementedError();

  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) =>
      throw UnimplementedError();

  @override
  int maxEncryptedSize(Uint8List inp) => throw UnimplementedError();
}
