import 'package:hive_ce/hive_ce.dart';
import 'package:storage_benchmark/hive_fixture_codec.dart';
import 'package:storage_benchmark/test_model.dart';

class TestModelAdapter extends TypeAdapter<TestModel> {
  @override
  final typeId = 0;

  @override
  TestModel read(BinaryReader reader) =>
      readHiveFixture(reader.readByte, reader.read);

  @override
  void write(BinaryWriter writer, TestModel obj) =>
      writeHiveFixture(obj, writer.writeByte, writer.write);
}
