import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/builder.dart';
import 'package:hive_ce_generator/src/class_builder.dart';
import 'package:hive_ce_generator/src/enum_builder.dart';
import 'package:hive_ce_generator/src/helper.dart';
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
    final gettersAndSetters = getAccessors(cls, library);

    final getters = gettersAndSetters[0];
    verifyFieldIndices(getters);

    final setters = gettersAndSetters[1];
    verifyFieldIndices(setters);

    final typeId = getTypeId(annotation);

    final adapterName = getAdapterName(cls.name, annotation);
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
  Set<String> getAllAccessorNames(InterfaceElement cls) {
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
  List<List<AdapterField>> getAccessors(
    InterfaceElement cls,
    LibraryElement library,
  ) {
    final accessorNames = getAllAccessorNames(cls);

    final constructor = cls.constructors.firstWhere((e) => e.name.isEmpty);
    final parameterDefaults = {
      for (final param in constructor.parameters)
        param.name: param.defaultValueCode,
    };

    AdapterField? accessorToField(PropertyAccessorElement? element) {
      if (element == null) return null;

      final annotation =
          getHiveFieldAnn(element.variable2) ?? getHiveFieldAnn(element);
      if (annotation == null) return null;

      final field = element.variable2!;
      return AdapterField(
        annotation.index,
        field.name,
        field.type,
        annotation.defaultValue,
        parameterDefaults[field.name],
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

    return [getters, setters];
  }

  /// TODO: Document this!
  void verifyFieldIndices(List<AdapterField> fields) {
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

  /// TODO: Document this!
  int getTypeId(ConstantReader annotation) {
    check(
      !annotation.read('typeId').isNull,
      'You have to provide a non-null typeId.',
    );
    return annotation.read('typeId').intValue;
  }
}
