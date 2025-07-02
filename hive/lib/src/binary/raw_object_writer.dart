import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';

/// A binary writer that writes raw objects
class RawObjectWriter extends BinaryWriterImpl {
  /// Constructor
  RawObjectWriter() : super(TypeRegistryImpl());

  @override
  void write<T>(T value, {bool withTypeId = true}) {
    if (value == null ||
        value is int ||
        value is double ||
        value is bool ||
        value is String ||
        value is List ||
        value is Set ||
        value is Map) {
      super.write(value, withTypeId: withTypeId);
      return;
    }

    final resolved = typeRegistry.findAdapterForValue(value);
    if (resolved == null) {
      throw HiveError('Cannot write, unknown type: ${value.runtimeType}. '
          'Did you forget to register an adapter?');
    }

    final nested = BinaryWriterImpl(typeRegistry);
    resolved.adapter.write(nested, value);
    final bytes = nested.toBytes();

    if (withTypeId) writeTypeId(resolved.typeId);
    writeByte(bytes.length);
    writeBytes(bytes);
  }
}
