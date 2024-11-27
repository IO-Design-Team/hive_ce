import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive_ce/src/crypto/aes_cbc_pkcs7.dart';
import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:hive_ce/src/crypto/hive_cipher.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:meta/meta.dart';

/// Default encryption algorithm. Uses AES256 CBC with PKCS7 padding.
class HiveAesCipher implements HiveCipher {
  static final _ivRandom = Random.secure();

  late final AesCbcPkcs7 _cipher;

  late final int _keyCrc;

  /// Create a cipher with the given [key].
  HiveAesCipher(List<int> key) {
    if (key.length != 32 || key.any((it) => it < 0 || it > 255)) {
      throw ArgumentError(
        'The encryption key has to be a 32 byte (256 bit) array.',
      );
    }

    final keyBytes = Uint8List.fromList(key);
    _cipher = AesCbcPkcs7(keyBytes);
    _keyCrc = Crc32.compute(sha256.convert(keyBytes).bytes as Uint8List);
  }

  @override
  int calculateKeyCrc() => _keyCrc;

  @override
  int decrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final iv = inp.view(inpOff, 16);

    return _cipher.decrypt(iv, inp, inpOff + 16, inpLength - 16, out, 0);
  }

  /// Generates a random initialization vector (internal)
  @visibleForTesting
  Uint8List generateIv() => _ivRandom.nextBytes(16);

  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final iv = generateIv();
    out.setAll(outOff, iv);

    final len = _cipher.encrypt(iv, inp, 0, inpLength, out, outOff + 16);

    return len + 16;
  }

  @override
  int maxEncryptedSize(Uint8List inp) {
    return inp.length + 32; // 16 IV + 16 extra for padding
  }
}
