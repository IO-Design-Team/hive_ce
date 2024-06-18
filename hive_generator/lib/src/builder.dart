import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// TODO: Document this!
class AdapterField {
  /// TODO: Document this!
  final int index;

  /// TODO: Document this!
  final String name;

  /// TODO: Document this!
  final DartType type;

  /// TODO: Document this!
  final DartObject? defaultValue;

  /// TODO: Document this!
  AdapterField(this.index, this.name, this.type, this.defaultValue);
}

/// TODO: Document this!
abstract class Builder {
  /// TODO: Document this!
  final InterfaceElement cls;

  /// TODO: Document this!
  final List<AdapterField> getters;

  /// TODO: Document this!
  final List<AdapterField> setters;

  /// TODO: Document this!
  Builder(this.cls, this.getters, [this.setters = const <AdapterField>[]]);

  /// TODO: Document this!
  String buildRead();

  /// TODO: Document this!
  String buildWrite();
}
