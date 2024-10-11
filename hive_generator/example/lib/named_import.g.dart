// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: unnecessary_const, require_trailing_commas, unnecessary_breaks, document_ignores

part of 'named_import.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NamedImportTypeAdapter extends TypeAdapter<NamedImportType> {
  @override
  final int typeId = 100;

  @override
  NamedImportType read(BinaryReader reader) {
    return NamedImportType();
  }

  @override
  void write(BinaryWriter writer, NamedImportType obj) {
    writer.writeByte(0);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NamedImportTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
