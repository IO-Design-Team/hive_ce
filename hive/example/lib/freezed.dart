import 'package:freezed_annotation/freezed_annotation.dart';

part 'freezed.freezed.dart';

@freezed
class FreezedPerson with _$FreezedPerson {
  const factory FreezedPerson({
    required String firstName,
    @Default('') String middleName,
    required String lastName,
    required int age,
  }) = _FreezedPerson;
}
