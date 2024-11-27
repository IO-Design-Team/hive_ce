// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'freezed.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FreezedPerson {
  String get firstName => throw _privateConstructorUsedError;
  String get lastName => throw _privateConstructorUsedError;
  int get age => throw _privateConstructorUsedError;

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FreezedPersonCopyWith<FreezedPerson> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FreezedPersonCopyWith<$Res> {
  factory $FreezedPersonCopyWith(
          FreezedPerson value, $Res Function(FreezedPerson) then) =
      _$FreezedPersonCopyWithImpl<$Res, FreezedPerson>;
  @useResult
  $Res call({String firstName, String lastName, int age});
}

/// @nodoc
class _$FreezedPersonCopyWithImpl<$Res, $Val extends FreezedPerson>
    implements $FreezedPersonCopyWith<$Res> {
  _$FreezedPersonCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? firstName = null,
    Object? lastName = null,
    Object? age = null,
  }) {
    return _then(_value.copyWith(
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      age: null == age
          ? _value.age
          : age // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FreezedPersonImplCopyWith<$Res>
    implements $FreezedPersonCopyWith<$Res> {
  factory _$$FreezedPersonImplCopyWith(
          _$FreezedPersonImpl value, $Res Function(_$FreezedPersonImpl) then) =
      __$$FreezedPersonImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String firstName, String lastName, int age});
}

/// @nodoc
class __$$FreezedPersonImplCopyWithImpl<$Res>
    extends _$FreezedPersonCopyWithImpl<$Res, _$FreezedPersonImpl>
    implements _$$FreezedPersonImplCopyWith<$Res> {
  __$$FreezedPersonImplCopyWithImpl(
      _$FreezedPersonImpl _value, $Res Function(_$FreezedPersonImpl) _then)
      : super(_value, _then);

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? firstName = null,
    Object? lastName = null,
    Object? age = null,
  }) {
    return _then(_$FreezedPersonImpl(
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      age: null == age
          ? _value.age
          : age // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$FreezedPersonImpl implements _FreezedPerson {
  const _$FreezedPersonImpl(
      {required this.firstName, required this.lastName, required this.age});

  @override
  final String firstName;
  @override
  final String lastName;
  @override
  final int age;

  @override
  String toString() {
    return 'FreezedPerson(firstName: $firstName, lastName: $lastName, age: $age)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FreezedPersonImpl &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.age, age) || other.age == age));
  }

  @override
  int get hashCode => Object.hash(runtimeType, firstName, lastName, age);

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FreezedPersonImplCopyWith<_$FreezedPersonImpl> get copyWith =>
      __$$FreezedPersonImplCopyWithImpl<_$FreezedPersonImpl>(this, _$identity);
}

abstract class _FreezedPerson implements FreezedPerson {
  const factory _FreezedPerson(
      {required final String firstName,
      required final String lastName,
      required final int age}) = _$FreezedPersonImpl;

  @override
  String get firstName;
  @override
  String get lastName;
  @override
  int get age;

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FreezedPersonImplCopyWith<_$FreezedPersonImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
