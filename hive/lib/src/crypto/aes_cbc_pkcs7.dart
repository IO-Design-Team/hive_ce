import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:meta/meta.dart';

/// AES CBC implementation with PKCS7 padding
@immutable
class AesCbcPkcs7 {
  static final _lastInputBlockBuffer = Uint8List(16);
  static final _cbcVBuffer = Uint8List(16);

  final Uint8List _keyBytes;

  late final List<Uint32List> _encryptionKey =
      AesEngine.generateWorkingKey(_keyBytes, true);
  late final List<Uint32List> _decryptionKey =
      AesEngine.generateWorkingKey(_keyBytes, false);

  /// Not part of public API
  AesCbcPkcs7(this._keyBytes);

  /// Not part of public API
  int encrypt(
    Uint8List iv,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff, {
    int ivOff = 0,
  }) {
    final cbcV = _cbcVBuffer;
    cbcV.setRange(0, aesBlockSize, iv, ivOff);

    final inputBlocks = (inpLength + aesBlockSize) ~/ aesBlockSize;
    final remaining = inpLength % aesBlockSize;

    var offset = 0;
    for (var i = 0; i < inputBlocks - 1; i++) {
      // XOR the cbcV and the input, then encrypt the cbcV
      for (var i = 0; i < aesBlockSize; i++) {
        cbcV[i] ^= inp[inpOff + offset + i];
      }

      AesEngine.encryptBlock(_encryptionKey, cbcV, 0, out, outOff + offset);

      // copy ciphertext to cbcV
      cbcV.setRange(0, aesBlockSize, out, outOff + offset);
      offset += aesBlockSize;
    }

    final lastInputBlock = _lastInputBlockBuffer;
    lastInputBlock.setRange(0, remaining, inp, inpOff + offset);
    lastInputBlock.fillRange(remaining, aesBlockSize, aesBlockSize - remaining);

    for (var i = 0; i < aesBlockSize; i++) {
      cbcV[i] ^= lastInputBlock[i];
    }
    AesEngine.encryptBlock(_encryptionKey, cbcV, 0, out, outOff + offset);

    return offset + aesBlockSize;
  }

  /// Not part of public API
  int decrypt(
    Uint8List iv,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff, {
    int ivOff = 0,
  }) {
    if (inpLength < aesBlockSize || inpLength % aesBlockSize != 0) {
      throw ArgumentError('Invalid or corrupted pad block');
    }

    final inputBlocks = inpLength ~/ aesBlockSize;

    var offset = 0;

    AesEngine.decryptBlock(_decryptionKey, inp, inpOff, out, outOff);
    for (var i = 0; i < aesBlockSize; i++) {
      out[outOff + i] ^= iv[ivOff + i];
    }
    offset += aesBlockSize;

    for (var i = 0; i < inputBlocks - 1; i++) {
      AesEngine.decryptBlock(
        _decryptionKey,
        inp,
        inpOff + offset,
        out,
        outOff + offset,
      );
      for (var i = 0; i < aesBlockSize; i++) {
        out[outOff + offset + i] ^= inp[inpOff - aesBlockSize + offset + i];
      }
      offset += aesBlockSize;
    }

    final lastDecryptedByte = out[outOff + offset - 1];
    if (lastDecryptedByte == 0 || lastDecryptedByte > aesBlockSize) {
      throw ArgumentError('Invalid or corrupted pad block');
    }
    for (var i = 1; i < lastDecryptedByte; i++) {
      if (out[outOff + offset - i - 1] != lastDecryptedByte) {
        throw ArgumentError('Invalid or corrupted pad block');
      }
    }

    return offset - lastDecryptedByte;
  }
}
