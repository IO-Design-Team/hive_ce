// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class PersonAdapter extends TypeAdapter<Person> {
  @override
  final typeId = 0;

  @override
  Person read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    dynamic field0, field1, field2, field3, field4;
    for (var i = 0; i < numOfFields; i++) {
      switch (reader.readByte()) {
        case 0:
          field0 = reader.read();
        case 1:
          field1 = reader.read();
        case 2:
          field2 = reader.read();
        case 3:
          field3 = reader.read();
        case 4:
          field4 = reader.read();
        default:
          reader.read();
      }
    }
    return Person(
      name: field0 as String,
      age: (field1 as num).toInt(),
      bestFriend: field2 as Person?,
      friends: field3 == null ? const [] : (field3 as List).cast<Person>(),
      job: field4 == null ? Job.unemployed : field4 as Job,
    );
  }

  @override
  void write(BinaryWriter writer, Person obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.bestFriend)
      ..writeByte(3)
      ..write(obj.friends)
      ..writeByte(4)
      ..write(obj.job);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class JobAdapter extends TypeAdapter<Job> {
  @override
  final typeId = 1;

  @override
  Job read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Job.softwareEngineer;
      case 1:
        return Job.productManager;
      case 2:
        return Job.designer;
      case 3:
        return Job.sales;
      case 4:
        return Job.marketing;
      case 5:
        return Job.hr;
      case 6:
        return Job.finance;
      case 7:
        return Job.unemployed;
      default:
        return Job.softwareEngineer;
    }
  }

  @override
  void write(BinaryWriter writer, Job obj) {
    switch (obj) {
      case Job.softwareEngineer:
        writer.writeByte(0);
      case Job.productManager:
        writer.writeByte(1);
      case Job.designer:
        writer.writeByte(2);
      case Job.sales:
        writer.writeByte(3);
      case Job.marketing:
        writer.writeByte(4);
      case Job.hr:
        writer.writeByte(5);
      case Job.finance:
        writer.writeByte(6);
      case Job.unemployed:
        writer.writeByte(7);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
