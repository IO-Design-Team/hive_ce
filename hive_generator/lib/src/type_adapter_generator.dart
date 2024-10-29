import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/builder.dart';
import 'package:hive_ce_generator/src/class_builder.dart';
import 'package:hive_ce_generator/src/enum_builder.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';

/// TODO: Document this!
class TypeAdapterGenerator extends GeneratorForAnnotation<HiveType> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final cls = getClass(element);
    final library = await buildStep.inputLibrary;
    final getAccessorsResult = _getAccessors(cls: cls, library: library);

    final getters = getAccessorsResult.getters;
    _verifyFieldIndices(getters);

    final setters = getAccessorsResult.setters;
    _verifyFieldIndices(setters);

    final typeId = readTypeId(annotation);

    final adapterName =
        readAdapterName(annotation) ?? generateAdapterName(cls.name);
    final builder = cls.thisType.isEnum
        ? EnumBuilder(cls, getters)
        : ClassBuilder(cls, getters, setters);

    return '''
    class $adapterName extends TypeAdapter<${cls.name}> {
      @override
      final int typeId = $typeId;

      @override
      ${cls.name} read(BinaryReader reader) {
        ${builder.buildRead()}
      }

      @override
      void write(BinaryWriter writer, ${cls.name} obj) {
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
  }

  /// TODO: Document this!
  Set<String> _getAllAccessorNames(InterfaceElement cls) {
    final accessorNames = <String>{};

    final supertypes = cls.allSupertypes.map((it) => it.element);
    for (final type in [cls, ...supertypes]) {
      for (final accessor in type.accessors) {
        final name = accessor.name;
        if (accessor.isSetter) {
          // Remove '=' from setter name
          accessorNames.add(name.substring(0, name.length - 1));
        } else {
          accessorNames.add(name);
        }
      }
    }

    return accessorNames;
  }

  /// TODO: Document this!
  _GetAccessorsResult _getAccessors({
    required InterfaceElement cls,
    required LibraryElement library,
  }) {
    final accessorNames = _getAllAccessorNames(cls);

    final constr = getConstructor(cls);
    final parameterDefaults = {
      for (final param in constr.parameters) param.name: param.defaultValueCode,
    };

    AdapterField? accessorToField(PropertyAccessorElement? element) {
      if (element == null) return null;

      final annotation =
          getHiveFieldAnn(element.variable2) ?? getHiveFieldAnn(element);
      if (annotation == null) return null;

      final field = element.variable2!;
      final name = field.name;
      return AdapterField(
        annotation.index,
        name,
        field.type,
        annotation.defaultValue,
        parameterDefaults[name],
      );
    }

    final getters = <AdapterField>[];
    final setters = <AdapterField>[];
    for (final name in accessorNames) {
      final getter = cls.augmented.lookUpGetter(name: name, library: library);
      final getterField = accessorToField(getter);
      if (getterField != null) getters.add(getterField);

      final setter =
          cls.augmented.lookUpSetter(name: '$name=', library: library);
      final setterField = accessorToField(setter);
      if (setterField != null) setters.add(setterField);
    }

    return _GetAccessorsResult(getters, setters);
  }

  /// TODO: Document this!
  void _verifyFieldIndices(List<AdapterField> fields) {
    for (final field in fields) {
      if (field.index < 0 || field.index > 255) {
        throw 'Field numbers can only be in the range 0-255.';
      }

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

  const _GetAccessorsResult(this.getters, this.setters);
}
