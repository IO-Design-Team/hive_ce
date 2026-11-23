import 'package:test/test.dart';

import 'integration.dart';

void main() {
  hiveIntegrationTest((type) {
    group(
      'lazy box adaptive read-ahead',
      () {
        test('reads sequential, large, random, and concurrent values',
            () async {
          final hive = await createHive(type: type);
          var (_, box) = await openBox<String>(true, type: type, hive: hive);

          // Exceed 16 KB across many small frames plus a > 16 KB frame.
          const count = 450;
          const largeIndex = 200;
          final largeValue = 'L' * 20000;

          final entries = <String, String>{};
          for (var i = 0; i < count; i++) {
            entries['key_$i'] =
                i == largeIndex ? largeValue : 'value_${i}_${'x' * 48}';
          }
          await box.putAll(entries);

          box = await hive.reopenBox<String>(box);

          // Sequential scan across multiple 16 KB windows and a > 16 KB value.
          for (var i = 0; i < count; i++) {
            expect(await box.get('key_$i'), entries['key_$i']);
          }

          // Non-contiguous random gets across the box.
          for (var i = count - 1; i >= 0; i -= 17) {
            expect(await box.get('key_$i'), entries['key_$i']);
          }
          expect(await box.get('key_$largeIndex'), largeValue);

          // Concurrent sequential gets serialized cleanly via ReadWriteSync.
          final futures = <Future<String?>>[
            for (var i = 0; i < count; i++)
              Future<String?>.value(box.get('key_$i')),
          ];
          final results = await Future.wait(futures);
          for (var i = 0; i < count; i++) {
            expect(results[i], entries['key_$i']);
          }

          await box.close();
        });

        test('invalidates read-ahead on compact, clear, and close', () async {
          final hive = await createHive(type: type);
          var (_, box) = await openBox<String>(true, type: type, hive: hive);

          const count = 350;
          for (var i = 0; i < count; i++) {
            await box.put('k$i', 'initial_${i}_${'a' * 50}');
          }
          // Reopen so keystore offsets reflect on-disk layout cleanly.
          box = await hive.reopenBox<String>(box);

          // Warm sequential read-ahead, then delete entries and compact.
          for (var i = 0; i < 20; i++) {
            expect(await box.get('k$i'), 'initial_${i}_${'a' * 50}');
          }
          await box.deleteAll([for (var i = 0; i < count; i += 2) 'k$i']);
          await box.compact();

          for (var i = 0; i < count; i++) {
            if (i.isEven) {
              expect(await box.get('k$i'), isNull);
            } else {
              expect(await box.get('k$i'), 'initial_${i}_${'a' * 50}');
            }
          }

          // Warm read-ahead again, then clear and write new values.
          for (var i = 1; i < 40; i += 2) {
            expect(await box.get('k$i'), 'initial_${i}_${'a' * 50}');
          }
          await box.clear();
          for (var i = 0; i < 100; i++) {
            await box.put('k$i', 'after_clear_$i');
          }
          for (var i = 0; i < 100; i++) {
            expect(await box.get('k$i'), 'after_clear_$i');
          }

          // Warm read-ahead, then close and reopen.
          box = await hive.reopenBox<String>(box);
          for (var i = 0; i < 100; i++) {
            expect(await box.get('k$i'), 'after_clear_$i');
          }

          await box.close();
        });

        test('works with encrypted lazy boxes', () async {
          final hive = await createHive(type: type);
          final key = List<int>.filled(32, 7);
          var (_, box) = await openBox<String>(
            true,
            type: type,
            hive: hive,
            encryptionKey: key,
          );

          const count = 350;
          final entries = <String, String>{
            for (var i = 0; i < count; i++) 'enc_$i': 'secret_${i}_${'z' * 50}',
          };
          await box.putAll(entries);

          box = await hive.reopenBox<String>(box, encryptionKey: key);

          for (var i = 0; i < count; i++) {
            expect(await box.get('enc_$i'), entries['enc_$i']);
          }
          for (var i = count - 1; i >= 0; i -= 13) {
            expect(await box.get('enc_$i'), entries['enc_$i']);
          }

          await box.close();
        });
      },
      timeout: longTimeout,
    );
  });
}
