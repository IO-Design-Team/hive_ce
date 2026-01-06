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
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Person(
      name: fields[0] as String,
      age: (fields[1] as num).toInt(),
      bestFriend: fields[2] as Person?,
      friends: fields[3] == null
          ? const []
          : (fields[3] as List).cast<Person>(),
      job: fields[4] == null ? Job.unemployed : fields[4] as Job,
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
