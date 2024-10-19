import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/builder.dart';
import 'package:hive_ce_generator/src/class_builder.dart';
import 'package:hive_ce_generator/src/enum_builder.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';

/// TODO: Document this!
class TypeAdapterGenerator extends GeneratorForAnnotation<HiveType> {
  static const _classIgnoredFields = {'hashCode', 'runtimeType'};
  static const _enumIgnoredFields = {'values', 'value', 'index'};

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final result = generateTypeAdapter(
      element: element,
      library: await buildStep.inputLibrary,
      typeId: readTypeId(annotation),
      adapterName: readAdapterName(annotation),
    );
    return result.content;
  }

  static GenerateTypeAdapterResult generateTypeAdapter({
    required Element element,
    required LibraryElement library,
    required int typeId,
    String? adapterName,
    HiveSchemaType? schema,
  }) {
    final clazz = getClass(element);
    final getAccessorsResult =
        _getAccessors(clazz: clazz, library: library, schema: schema);

    final getters = getAccessorsResult.getters;
    _verifyFieldIndices(getters);

    final setters = getAccessorsResult.setters;
    _verifyFieldIndices(setters);

    adapterName ??= generateAdapterName(clazz.name);
    final builder = clazz.thisType.isEnum
        ? EnumBuilder(clazz, getters)
        : ClassBuilder(clazz, getters, setters);

    final content = '''
    class $adapterName extends TypeAdapter<${clazz.name}> {
      @override
      final int typeId = $typeId;

      @override
      ${clazz.name} read(BinaryReader reader) {
        ${builder.buildRead()}
      }

      @override
      void write(BinaryWriter writer, ${clazz.name} obj) {
        ${builder.buildWrite()}
      }

      @override
      int get hashCode => typeId.hashCode;

      @override
      bool operator ==(Object other) =>
          identical(this, other) ||
          other is $adapterName &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
    }
    ''';

    return GenerateTypeAdapterResult(content, getAccessorsResult.schema);
  }

  /// TODO: Document this!
  static Set<String> _getAllAccessorNames(InterfaceElement cls) {
    final accessorNames = <String>{};

    final supertypes = cls.allSupertypes.map((it) => it.element);
    for (final type in [cls, ...supertypes]) {
      for (final accessor in type.accessors) {
        if (accessor.isSetter) {
          final name = accessor.name;
          accessorNames.add(name.substring(0, name.length - 1));
        } else {
          accessorNames.add(accessor.name);
        }
      }
    }

    return accessorNames;
  }

  /// TODO: Document this!
  static _GetAccessorsResult _getAccessors({
    required InterfaceElement clazz,
    required LibraryElement library,
    HiveSchemaType? schema,
  }) {
    final ignoredFields =
        clazz.thisType.isEnum ? _enumIgnoredFields : _classIgnoredFields;
    final accessorNames = _getAllAccessorNames(clazz);

    final constructor = clazz.constructors.firstWhere((e) => e.name.isEmpty);
    final parameterDefaults = {
      for (final param in constructor.parameters)
        param.name: param.defaultValueCode,
    };

    var nextIndex = schema?.nextIndex ?? 0;
    final newSchemaFields = <String, HiveSchemaField>{};
    AdapterField? accessorToField(PropertyAccessorElement? element) {
      if (element == null) return null;

      final annotation =
          getHiveFieldAnn(element.variable2) ?? getHiveFieldAnn(element);
      if (schema == null && annotation == null) return null;

      final field = element.variable2!;
      final name = field.name;
      if (ignoredFields.contains(name)) return null;

      final index =
          annotation?.index ?? schema?.fields[name]?.index ?? nextIndex++;
      newSchemaFields[name] = HiveSchemaField(index: index);
      return AdapterField(
        index,
        name,
        field.type,
        annotation?.defaultValue,
        parameterDefaults[field.name],
      );
    }

    final getters = <AdapterField>[];
    final setters = <AdapterField>[];
    for (final name in accessorNames) {
      final getter = clazz.augmented.lookUpGetter(name: name, library: library);
      final getterField = accessorToField(getter);
      if (getterField != null) getters.add(getterField);

      final setter =
          clazz.augmented.lookUpSetter(name: '$name=', library: library);
      final setterField = accessorToField(setter);
      if (setterField != null) setters.add(setterField);
    }

    // Sort by index for deterministic output
    getters.sort((a, b) => a.index.compareTo(b.index));
    setters.sort((a, b) => a.index.compareTo(b.index));
    final newSchema = schema?.copyWith(
      nextIndex: nextIndex,
      fields: Map.fromEntries(
        newSchemaFields.entries.toList()
          ..sort((a, b) => a.value.index.compareTo(b.value.index)),
      ),
    );
    return _GetAccessorsResult(getters, setters, newSchema);
  }

  /// TODO: Document this!
  static void _verifyFieldIndices(List<AdapterField> fields) {
    for (final field in fields) {
      check(
        field.index >= 0 && field.index <= 255,
        'Field numbers can only be in the range 0-255.',
      );

      for (final otherField in fields) {
        if (otherField == field) continue;
        if (otherField.index == field.index) {
          throw HiveError(
            'Duplicate field number: ${field.index}. Fields "${field.name}" '
            'and "${otherField.name}" have the same number.',
          );
        }
      }
    }
  }
}

class _GetAccessorsResult {
  final List<AdapterField> getters;
  final List<AdapterField> setters;
  final HiveSchemaType? schema;

  _GetAccessorsResult(this.getters, this.setters, this.schema);
}

class GenerateTypeAdapterResult {
  final String content;
  final HiveSchemaType? schema;

  GenerateTypeAdapterResult(this.content, this.schema);
}
