import 'package:hive_ce_generator/src/adapter_builder/adapter_builder.dart';

/// TODO: Document this!
class EnumAdapterBuilder extends AdapterBuilder {
  /// TODO: Document this!
  const EnumAdapterBuilder(super.cls, super.getters);

  @override
  String buildRead() {
    if (getters.isEmpty) {
      throw '${cls.name} does not have any enum value.';
    }

    final code = StringBuffer();
    code.writeln('switch (reader.readByte()) {');

    for (final field in getters) {
      code.writeln('''
        case ${field.index}:
          return ${cls.name}.${field.name};''');
    }

    final defaultField = getters.firstWhere(
      (it) => it.annotationDefault?.toBoolValue() == true,
      orElse: () => getters.first,
    );
    code.writeln('''
      default:
        return ${cls.name}.${defaultField.name};
      }''');

    return code.toString();
  }

  @override
  String buildWrite() {
    final code = StringBuffer();
    code.writeln('switch (obj) {');

    for (final field in getters) {
      code.writeln('''
        case ${cls.name}.${field.name}:
          writer.writeByte(${field.index});''');
    }

    code.writeln('}');

    return code.toString();
  }
}
