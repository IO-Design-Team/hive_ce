import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:meta/meta.dart';

/// AES CBC implementation with PKCS7 padding
@immutable
class AesCbcPkcs7 {
  final Uint8List _keyBytes;

  late final Uint32List _encryptionKey = AesEngine.flattenWorkingKey(
    AesEngine.generateWorkingKey(_keyBytes, true),
  );
  late final Uint32List _decryptionKey = AesEngine.flattenWorkingKey(
    AesEngine.generateWorkingKey(_keyBytes, false),
  );

  /// Not part of public API
  AesCbcPkcs7(this._keyBytes);

  /// Not part of public API
  int encrypt(
    Uint8List iv,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    return AesEngine.encryptCbc(
      _encryptionKey,
      iv.readUint32(0),
      iv.readUint32(4),
      iv.readUint32(8),
      iv.readUint32(12),
      inp,
      inpOff,
      inpLength,
      out,
      outOff,
    );
  }

  /// Not part of public API
  int decrypt(
    Uint8List iv,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    if (inpLength < aesBlockSize || (inpLength & (aesBlockSize - 1)) != 0) {
      throw ArgumentError('Invalid or corrupted pad block');
    }

    return AesEngine.decryptCbc(
      _decryptionKey,
      iv.readUint32(0),
      iv.readUint32(4),
      iv.readUint32(8),
      iv.readUint32(12),
      inp,
      inpOff,
      inpLength,
      out,
      outOff,
    );
  }
}
