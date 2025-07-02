import 'package:hive_ce/src/binary/raw_object_reader.dart';
import 'package:hive_ce/src/binary/raw_object_writer.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/schema/hive_schema.dart';
import 'package:test/test.dart';

const stubSchema = HiveSchema(nextTypeId: 0, types: {});

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

      final br = RawObjectReader(stubSchema, bw.toBytes());
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

  test('adapter', () {
    final dateTime = DateTime.timestamp();

    final bw = RawObjectWriter(TypeRegistryImpl());
    bw.write(dateTime);
    bw.write(Duration(seconds: 123));

    final br = RawObjectReader(stubSchema, bw.toBytes());
    expect(br.read(), dateTime);
    expect(br.read(), Duration(seconds: 123));
  });
}
