import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initFlutter computes checksums with zlib', (tester) async {
    await Hive.initFlutter();
    final nativeCompute = Crc32.nativeCompute;
    addTearDown(() => Crc32.nativeCompute = nativeCompute);

    final bytes = Uint8List.fromList(List.generate(1000, (i) => i));
    Crc32.nativeCompute = null;
    expect(
      nativeCompute?.call(bytes, 0, 0, bytes.length),
      Crc32.compute(bytes),
    );
    expect(
      nativeCompute?.call(bytes, 0x1234abcd, 17, 500),
      Crc32.compute(bytes, crc: 0x1234abcd, offset: 17, length: 500),
    );
  }, skip: kIsWeb);

  testWidgets('IsolatedHive.initFlutter uses zlib checksums', (tester) async {
    await IsolatedHive.initFlutter();
    addTearDown(() async {
      await IsolatedHive.deleteBoxFromDisk('zlib_test');
      await IsolatedHive.close();
    });

    final box = await IsolatedHive.openBox<Uint8List>('zlib_test');
    final payload = Uint8List.fromList(List.generate(4096, (i) => i));
    await box.put('key', payload);
    await box.close();

    final reopened = await IsolatedHive.openBox<Uint8List>('zlib_test');
    expect(await reopened.get('key'), payload);
  }, skip: kIsWeb);
}
