import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/io/frame_io_helper.dart';
import 'package:hive_ce/src/object/hive_list_impl.dart';
import 'package:mocktail/mocktail.dart';

// Mocks

class MockBox<E> extends Mock implements Box<E> {
  @override
  final bool lazy;

  MockBox({this.lazy = false});
}

class MockChangeNotifier extends Mock implements ChangeNotifier {}

class MockStorageBackend extends Mock implements StorageBackend {}

class MockKeystore extends Mock implements Keystore {}

class MockHiveImpl extends Mock implements HiveImpl {}

class MockHiveList extends Mock implements HiveList {}

class MockHiveListImpl extends Mock implements HiveListImpl {}

class MockRandomAccessFile extends Mock implements RandomAccessFile {}

class MockBinaryReader extends Mock implements BinaryReader {}

class MockBinaryWriter extends Mock implements BinaryWriter {}

class MockFile extends Mock implements File {
  @override
  bool existsSync() => false;
}

class MockFrameIoHelper extends Mock implements FrameIoHelper {}

// Fakes

class KeystoreFake extends Fake implements Keystore {}

class TypeRegistryFake extends Fake implements TypeRegistry {}

// Dumb objects

class TestHiveObject extends HiveObject {}
