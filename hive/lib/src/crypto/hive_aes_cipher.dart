import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive_ce/src/crypto/aes_cbc_pkcs7.dart';
import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:hive_ce/src/crypto/hive_cipher.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:meta/meta.dart';

/// Default encryption algorithm. Uses AES256 CBC with PKCS7 padding.
@immutable
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
    return _cipher.decrypt(
      inp,
      inp,
      inpOff + 16,
      inpLength - 16,
      out,
      outOff,
      ivOff: inpOff,
    );
  }

  /// Generates a random initialization vector (internal)
  @visibleForTesting
  Uint8List generateIv() {
    final iv = Uint8List(16);
    iv.writeUint32(0, _ivRandom.nextInt(0x100000000));
    iv.writeUint32(4, _ivRandom.nextInt(0x100000000));
    iv.writeUint32(8, _ivRandom.nextInt(0x100000000));
    iv.writeUint32(12, _ivRandom.nextInt(0x100000000));
    return iv;
  }

  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    if (runtimeType == HiveAesCipher) {
      final iv0 = _ivRandom.nextInt(0x100000000);
      final iv1 = _ivRandom.nextInt(0x100000000);
      final iv2 = _ivRandom.nextInt(0x100000000);
      final iv3 = _ivRandom.nextInt(0x100000000);
      out.writeUint32(outOff, iv0);
      out.writeUint32(outOff + 4, iv1);
      out.writeUint32(outOff + 8, iv2);
      out.writeUint32(outOff + 12, iv3);

      final len = _cipher.encryptWithIvWords(
        iv0,
        iv1,
        iv2,
        iv3,
        inp,
        inpOff,
        inpLength,
        out,
        outOff + 16,
      );

      return len + 16;
    }

    final iv = generateIv();
    out.setRange(outOff, outOff + 16, iv);

    final len = _cipher.encrypt(iv, inp, inpOff, inpLength, out, outOff + 16);

    return len + 16;
  }

  @override
  int maxEncryptedSize(Uint8List inp) {
    return inp.length + 32; // 16 IV + 16 extra for padding
  }
}
