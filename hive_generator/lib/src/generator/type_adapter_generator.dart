import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator/src/adapter_builder/adapter_builder.dart';
import 'package:hive_ce_generator/src/adapter_builder/class_adapter_builder.dart';
import 'package:hive_ce_generator/src/adapter_builder/enum_adapter_builder.dart';
import 'package:hive_ce_generator/src/helper/helper.dart';
import 'package:hive_ce_generator/src/helper/type_helper.dart';
import 'package:hive_ce_generator/src/model/hive_schema.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';
import 'package:meta/meta.dart';

/// TODO: Document this!
class TypeAdapterGenerator extends GeneratorForAnnotation<HiveType> {
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

  /// Generate a type adapter with the given information
  ///
  /// If this is an incremental update, pass the existing [schema]
  static GenerateTypeAdapterResult generateTypeAdapter({
    required Element element,
    required LibraryElement library,
    required int typeId,
    String? adapterName,
    HiveSchemaType? schema,
    Set<String> ignoredFields = const {},
  }) {
    final cls = getClass(element);
    final getAccessorsResult = getAccessors(
      typeId: typeId,
      cls: cls,
      library: library,
      schema: schema,
      ignoredFields: ignoredFields,
    );

    final getters = getAccessorsResult.getters;
    _verifyFieldIndices(getters);

    final setters = getAccessorsResult.setters;
    _verifyFieldIndices(setters);

    adapterName ??= generateAdapterName(cls.displayName);
    final builder = cls.thisType.isEnum
        ? EnumAdapterBuilder(cls, getters)
        : ClassAdapterBuilder(cls, getters, setters);

    final content = '''
    class $adapterName extends TypeAdapter<${cls.displayName}> {
      @override
      final typeId = $typeId;

      @override
      ${cls.displayName} read(BinaryReader reader) {
        ${builder.buildRead()}
      }

      @override
      void write(BinaryWriter writer, ${cls.displayName} obj) {
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
    final isEnum = cls.thisType.isEnum;
    final constructorFields = getConstructor(cls)
        .formalParameters
        .map((it) => it.displayName)
        .toSet();

    final accessorNames = <String>{};

    final supertypes = cls.allSupertypes.map((it) => it.element);
    for (final type in [cls, ...supertypes]) {
      // Ignore Object base members
      if (const TypeChecker.typeNamed(Object, inPackage: 'core', inSdk: true)
          .isExactly(type)) {
        continue;
      }

      for (final accessor in [...type.getters, ...type.setters]) {
        // Ignore any non-enum accessors on enums
        if (isEnum && !accessor.returnType.isEnum) continue;

        // Ignore non-static fields on enums
        if (isEnum && !accessor.isStatic) continue;

        // Ignore static fields on classes
        if (!isEnum && accessor.isStatic) continue;

        // Ignore getters without setters on classes
        if (!isEnum &&
            accessor is GetterElement &&
            accessor.correspondingSetter == null &&
            !constructorFields.contains(accessor.displayName)) {
          continue;
        }

        // The display name does not have the trailing '=' for setters
        accessorNames.add(accessor.displayName);
      }
    }

    return accessorNames;
  }

  /// TODO: Document this!
  static GetAccessorsResult getAccessors({
    required int typeId,
    required InterfaceElement cls,
    required LibraryElement library,
    HiveSchemaType? schema,
    Set<String> ignoredFields = const {},
  }) {
    final accessorNames = _getAllAccessorNames(cls);

    final constr = getConstructor(cls);

    final parameterDefaults = <String, String?>{};
    for (final param in constr.formalParameters) {
      final freezedDefault = getFreezedDefault(param);
      if (freezedDefault != null) {
        parameterDefaults[param.displayName] = constantToString(freezedDefault);
      } else {
        parameterDefaults[param.displayName] = param.defaultValueCode;
      }
    }

    var nextIndex = schema?.nextIndex ?? 0;
    final newSchemaFields = <String, HiveSchemaField>{};

    AdapterField? accessorToField(PropertyAccessorElement? element) {
      if (element == null) return null;

      final annotation =
          getHiveFieldAnn(element.variable) ?? getHiveFieldAnn(element);
      if (schema == null && annotation == null) return null;

      final field = element.variable;
      final name = field.displayName;
      final int index;
      if (schema != null) {
        // Only generate one id per field name
        index = schema.fields[name]?.index ??
            newSchemaFields[name]?.index ??
            nextIndex++;
      } else if (annotation != null) {
        index = annotation.index;

        // Keep track of the next index for the migration tool
        if (index >= nextIndex) nextIndex = index + 1;
      } else {
        // This should be impossible
        throw HiveError('No index found');
      }

      newSchemaFields[name] = HiveSchemaField(index: index);
      return AdapterField(
        element,
        index,
        name,
        field.type,
        annotation?.defaultValue,
        parameterDefaults[name],
      );
    }

    final getters = <AdapterField>[];
    final setters = <AdapterField>[];
    for (final name in accessorNames) {
      final getter = cls.lookUpGetter(name: name, library: library);
      final getterField = accessorToField(getter);
      if (getterField != null) getters.add(getterField);

      final setter = cls.lookUpSetter(name: name, library: library);
      final setterField = accessorToField(setter);
      if (setterField != null) setters.add(setterField);
    }

    // Sort by index for deterministic output
    getters.sort((a, b) => a.index.compareTo(b.index));
    setters.sort((a, b) => a.index.compareTo(b.index));
    final newSchema = HiveSchemaType(
      typeId: typeId,
      nextIndex: nextIndex,
      fields: Map.fromEntries(
        newSchemaFields.entries.toList()
          ..sort((a, b) => a.value.index.compareTo(b.value.index)),
      ),
    );
    return GetAccessorsResult(getters, setters, newSchema);
  }

  /// TODO: Document this!
  static void _verifyFieldIndices(List<AdapterField> fields) {
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

/// Result of [TypeAdapterGenerator.getAccessors]
@immutable
class GetAccessorsResult {
  /// The getters of the class
  final List<AdapterField> getters;

  /// The setters of the class
  final List<AdapterField> setters;

  /// The Hive schema generated for the class
  final HiveSchemaType schema;

  /// Constructor
  const GetAccessorsResult(this.getters, this.setters, this.schema);
}

/// Result of [TypeAdapterGenerator.generateTypeAdapter]
@immutable
class GenerateTypeAdapterResult {
  /// The generated content
  final String content;

  /// The generated schema
  final HiveSchemaType schema;

  /// Constructor
  const GenerateTypeAdapterResult(this.content, this.schema);
}
