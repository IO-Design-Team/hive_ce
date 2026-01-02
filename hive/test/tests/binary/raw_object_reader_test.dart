import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/raw_object_reader.dart';
import 'package:hive_ce/src/binary/raw_object_writer.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/schema/hive_schema.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

void main() {
  group('RawObjectReader', () {
    test('primitive', () {
      final bw = RawObjectWriter(TypeRegistryImpl());
      bw.write(null);
      bw.write(123);
      bw.write(123.456);
      bw.write(true);
      bw.write('hello');
      bw.write([1, 2, 3]);
      bw.write({1, 2, 3});
      bw.write({1: 2, 3: 4});

      final br = RawObjectReader({}, bw.toBytes());
      expect(br.read(), null);
      expect(br.read(), 123);
      expect(br.read(), 123.456);
      expect(br.read(), true);
      expect(br.read(), 'hello');
      expect(br.read(), [1, 2, 3]);
      expect(br.read(), {1, 2, 3});
      expect(br.read(), {1: 2, 3: 4});
    });
  });

  test('internal adapter', () {
    final dateTime = DateTime.timestamp();

    final bw = RawObjectWriter(TypeRegistryImpl());
    bw.write(dateTime);
    bw.write(Duration(seconds: 123));

    final br = RawObjectReader({}, bw.toBytes());
    expect(
      (br.read() as DateTime).millisecondsSinceEpoch,
      dateTime.millisecondsSinceEpoch,
    );
    expect(br.read(), Duration(seconds: 123));
  });

  group('external adapter', () {
    test('with schema', () {
      final typeRegistry = TypeRegistryImpl()..registerAdapter(TestAdapter());
      final types = {
        'TestObject': HiveSchemaType(
          typeId: 100,
          nextIndex: 0,
          fields: {
            'field1': HiveSchemaField(index: 0),
            'field2': HiveSchemaField(index: 1),
          },
        ),
      };

      final testObject = TestObject('test', 123);

      final bw = RawObjectWriter(typeRegistry);
      bw.write(testObject);

      final br = RawObjectReader(types, bw.toBytes());
      final raw = br.read() as RawObject;
      expect(raw.fields[0].name, 'field1');
      expect(raw.fields[0].value, testObject.field1);
      expect(raw.fields[1].name, 'field2');
      expect(raw.fields[1].value, testObject.field2);
    });

    test('without schema', () {
      final typeRegistry = TypeRegistryImpl()..registerAdapter(TestAdapter());
      final testObject = TestObject('test', 123);

      final bw = RawObjectWriter(typeRegistry);
      bw.write(testObject);

      final bytes = bw.toBytes();
      final br = RawObjectReader({}, bytes);
      final raw = br.read() as Uint8List;
      expect(raw, bytes.sublist(6));
    });

    test('enum', () {
      final typeRegistry = TypeRegistryImpl()
        ..registerAdapter(TestEnumAdapter());
      final types = {
        'TestEnum': HiveSchemaType(
          typeId: 100,
          nextIndex: 0,
          fields: {
            'value1': HiveSchemaField(index: 0),
            'value2': HiveSchemaField(index: 1),
          },
        ),
      };

      final bw = RawObjectWriter(typeRegistry);
      bw.write(TestEnum.value1);

      final br = RawObjectReader(types, bw.toBytes());
      final raw = br.read() as RawEnum;
      expect(raw.name, 'TestEnum');
      expect(raw.value, 'value1');
    });

    /// This test exists to make test coverage happy
    ///
    /// The real test is in hive_ce_inspector/test/binary/raw_object_reader_test.dart
    test('TimeOfDay', () {
      final typeRegistry = TypeRegistryImpl();

      final hour = 12;
      final minute = 30;
      final totalMinutes = hour * 60 + minute;

      final bw = RawObjectWriter(typeRegistry);
      bw.writeTypeId(233);
      bw.writeByte(0);
      bw.writeInt32(8);
      bw.writeInt(totalMinutes);

      final br = RawObjectReader({}, bw.toBytes());
      final raw = br.read() as String;
      expect(raw, '$hour:$minute');
    });
  });
}

@immutable
class TestObject {
  final String field1;
  final int field2;

  const TestObject(this.field1, this.field2);
}

class TestAdapter extends TypeAdapter<TestObject> {
  @override
  final typeId = 100;

  @override
  TestObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestObject(
      fields[0] as String,
      (fields[1] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, TestObject obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.field1)
      ..writeByte(1)
      ..write(obj.field2);
  }
}

enum TestEnum {
  value1,
  value2,
}

class TestEnumAdapter extends TypeAdapter<TestEnum> {
  @override
  final typeId = 100;

  @override
  TestEnum read(BinaryReader reader) {
    return TestEnum.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, TestEnum obj) {
    writer.writeByte(obj.index);
  }
}
