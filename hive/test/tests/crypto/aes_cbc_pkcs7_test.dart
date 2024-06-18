import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_cbc_pkcs7.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

import 'message.dart';

PaddedBlockCipherImpl getCipher() {
  final pcCipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  pcCipher.init(
    true,
    PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), iv),
      null,
    ),
  );
  return pcCipher;
}

void main() {
  group('AesCbcPkcs7', () {
    test('.encrypt()', () {
      final out = Uint8List(1100);
      final cipher = AesCbcPkcs7(key);
      for (var i = 1; i < 1000; i++) {
        final input = message.view(0, i);
        final outLen = cipher.encrypt(iv, input, 0, i, out, 0);
        final pcOut = getCipher().process(input);

        expect(out.view(0, outLen), pcOut);
      }
    });

    test('.decrypt()', () {
      final out = Uint8List(1100);
      final cipher = AesCbcPkcs7(key);
      for (var i = 1; i < 1000; i++) {
        final input = message.view(0, i);
        final encrypted = getCipher().process(input);
        final outLen = cipher.decrypt(iv, encrypted, 0, encrypted.length, out, 0);
        expect(out.view(0, outLen), input);
      }
    });
  });
}
