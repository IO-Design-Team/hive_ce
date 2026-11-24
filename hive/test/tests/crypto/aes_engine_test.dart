import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:test/test.dart';

import 'message.dart';

void main() {
  group('AesEngine', () {
    test('.generateWorkingKey()', () {
      expect(AesEngine.generateWorkingKey(key, true), encryptionKey);
      expect(AesEngine.generateWorkingKey(key, false), decryptionKey);
    });
  });
}
