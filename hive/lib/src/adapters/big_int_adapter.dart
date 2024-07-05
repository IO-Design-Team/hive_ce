import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';

/// Adapter for BigInt
class BigIntAdapter extends TypeAdapter<BigInt> {
  @override
  final typeId = FrameValueType.bigInt;

  @override
  BigInt read(BinaryReader reader) {
    final len = reader.readByte();
    final intStr = reader.readString(len);
    return BigInt.parse(intStr);
  }

  @override
  void write(BinaryWriter writer, BigInt obj) {
    final intStr = obj.toString();
    writer.writeByte(intStr.length);
    writer.writeString(intStr, writeByteCount: false);
  }
}
