import 'dart:typed_data';

import 'package:hive_ce/src/backend/storage_backend_memory.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  group('StorageBackendMemory', () {
    test('.path is null', () {
      final backend = StorageBackendMemory(null, null);
      expect(backend.path, null);
    });

    test('.supportsCompaction is false', () {
      final backend = StorageBackendMemory(null, null);
      expect(backend.supportsCompaction, false);
    });

    group('.initialize()', () {
      test('throws if frames cannot be decoded', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final backend = StorageBackendMemory(bytes, null);
        expect(
          () => backend.initialize(TypeRegistryImpl.nullImpl, null, false),
          throwsHiveError(['Wrong checksum']),
        );
      });
    });

    test('.readValue() throws UnsupportedError', () {
      final backend = StorageBackendMemory(null, null);
      expect(
        () => backend.readValue(Frame('key', 'val')),
        throwsUnsupportedError,
      );
    });

    test('.writeFrames() does nothing', () async {
      final backend = StorageBackendMemory(null, null);
      await backend.writeFrames([Frame('key', 'val')]);
    });

    test('.compact() throws UnsupportedError', () {
      final backend = StorageBackendMemory(null, null);
      expect(() => backend.compact([]), throwsUnsupportedError);
    });

    test('.clear() does nothing', () async {
      final backend = StorageBackendMemory(null, null);
      await backend.clear();
    });

    test('.close() does nothing', () async {
      final backend = StorageBackendMemory(null, null);
      await backend.close();
    });

    test('.deleteFromDisk() throws UnsupportedError', () {
      final backend = StorageBackendMemory(null, null);
      expect(backend.deleteFromDisk, throwsUnsupportedError);
    });
  });
}
