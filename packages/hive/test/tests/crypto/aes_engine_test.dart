import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:test/test.dart';

import 'message.dart';

void main() {
  group('AesEngine', () {
    test('.generateWorkingKey()', () {
      expect(AesEngine.generateWorkingKey(key, true), encryptionKey);
      expect(AesEngine.generateWorkingKey(key, false), decryptionKey);
    });

    test('.encryptBlock()', () {
      final out = Uint8List(message.length);

      final pcEngine = AESEngine();
      final outPc = Uint8List(message.length);

      for (var i = 0; i < message.length; i += aesBlockSize) {
        AesEngine.encryptBlock(encryptionKey, message, i, out, i);
        pcEngine.init(true, KeyParameter(key));
        pcEngine.processBlock(message, i, outPc, i);
      }
      expect(out, outPc);
    });

    test('.decryptBlock()', () {
      final out = Uint8List(message.length);

      final pcEngine = AESEngine();
      final encrypted = Uint8List(message.length);

      for (var i = 0; i < message.length; i += aesBlockSize) {
        AesEngine.decryptBlock(encryptionKey, message, i, out, i);
        pcEngine.init(true, KeyParameter(key));
        pcEngine.processBlock(message, i, encrypted, i);
      }

      for (var i = 0; i < encrypted.length; i += aesBlockSize) {
        AesEngine.decryptBlock(decryptionKey, encrypted, i, out, i);
      }
      expect(out, message);
    });
  });
}
