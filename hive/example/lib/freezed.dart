import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'freezed.freezed.dart';
part 'freezed.g.dart';

@freezed
@HiveType(typeId: 100)
class FreezedPerson with _$FreezedPerson {
  const factory FreezedPerson({
    @HiveField(0) required String firstName,
    @HiveField(1) required String lastName,
    @HiveField(2) required int age,
  }) = _FreezedPerson;
}
