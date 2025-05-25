import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

/// Metadata about a field in a class adapter
@immutable
class AdapterField {
  /// The corresponding element for this field
  /// TODO: Fix with analyzer 8
  /// ignore: deprecated_member_use
  final PropertyAccessorElement element;

  /// The index of the field
  ///
  /// Determines the order fields are read and written
  final int index;

  /// The name of the field
  final String name;

  /// The type of the field
  final DartType type;

  /// A default value provided by the field annotation
  final DartObject? annotationDefault;

  /// A default value provided by the constructor
  final String? constructorDefault;

  /// Constructor
  const AdapterField(
    this.element,
    this.index,
    this.name,
    this.type,
    this.annotationDefault,
    this.constructorDefault,
  );
}

/// TODO: Document this!
@immutable
abstract class AdapterBuilder {
  /// TODO: Document this!
  /// TODO: Fix with analyzer 8
  /// ignore: deprecated_member_use
  final InterfaceElement cls;

  /// TODO: Document this!
  final List<AdapterField> getters;

  /// TODO: Document this!
  final List<AdapterField> setters;

  /// TODO: Document this!
  const AdapterBuilder(
    this.cls,
    this.getters, [
    this.setters = const <AdapterField>[],
  ]);

  /// TODO: Document this!
  String buildRead();

  /// TODO: Document this!
  String buildWrite();
}
