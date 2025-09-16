// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'freezed.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FreezedPerson {
  String get firstName;
  String get middleName;
  String get lastName;
  int get age;

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FreezedPersonCopyWith<FreezedPerson> get copyWith =>
      _$FreezedPersonCopyWithImpl<FreezedPerson>(
          this as FreezedPerson, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FreezedPerson &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.middleName, middleName) ||
                other.middleName == middleName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.age, age) || other.age == age));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, firstName, middleName, lastName, age);

  @override
  String toString() {
    return 'FreezedPerson(firstName: $firstName, middleName: $middleName, lastName: $lastName, age: $age)';
  }
}

/// @nodoc
abstract mixin class $FreezedPersonCopyWith<$Res> {
  factory $FreezedPersonCopyWith(
          FreezedPerson value, $Res Function(FreezedPerson) _then) =
      _$FreezedPersonCopyWithImpl;
  @useResult
  $Res call({String firstName, String middleName, String lastName, int age});
}

/// @nodoc
class _$FreezedPersonCopyWithImpl<$Res>
    implements $FreezedPersonCopyWith<$Res> {
  _$FreezedPersonCopyWithImpl(this._self, this._then);

  final FreezedPerson _self;
  final $Res Function(FreezedPerson) _then;

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? firstName = null,
    Object? middleName = null,
    Object? lastName = null,
    Object? age = null,
  }) {
    return _then(_self.copyWith(
      firstName: null == firstName
          ? _self.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      middleName: null == middleName
          ? _self.middleName
          : middleName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _self.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      age: null == age
          ? _self.age
          : age // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [FreezedPerson].
extension FreezedPersonPatterns on FreezedPerson {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_FreezedPerson value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FreezedPerson() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_FreezedPerson value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreezedPerson():
        return $default(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_FreezedPerson value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreezedPerson() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String firstName, String middleName, String lastName, int age)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FreezedPerson() when $default != null:
        return $default(
            _that.firstName, _that.middleName, _that.lastName, _that.age);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String firstName, String middleName, String lastName, int age)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreezedPerson():
        return $default(
            _that.firstName, _that.middleName, _that.lastName, _that.age);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String firstName, String middleName, String lastName, int age)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreezedPerson() when $default != null:
        return $default(
            _that.firstName, _that.middleName, _that.lastName, _that.age);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FreezedPerson implements FreezedPerson {
  const _FreezedPerson(
      {required this.firstName,
      this.middleName = '',
      required this.lastName,
      required this.age});

  @override
  final String firstName;
  @override
  @JsonKey()
  final String middleName;
  @override
  final String lastName;
  @override
  final int age;

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FreezedPersonCopyWith<_FreezedPerson> get copyWith =>
      __$FreezedPersonCopyWithImpl<_FreezedPerson>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FreezedPerson &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.middleName, middleName) ||
                other.middleName == middleName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.age, age) || other.age == age));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, firstName, middleName, lastName, age);

  @override
  String toString() {
    return 'FreezedPerson(firstName: $firstName, middleName: $middleName, lastName: $lastName, age: $age)';
  }
}

/// @nodoc
abstract mixin class _$FreezedPersonCopyWith<$Res>
    implements $FreezedPersonCopyWith<$Res> {
  factory _$FreezedPersonCopyWith(
          _FreezedPerson value, $Res Function(_FreezedPerson) _then) =
      __$FreezedPersonCopyWithImpl;
  @override
  @useResult
  $Res call({String firstName, String middleName, String lastName, int age});
}

/// @nodoc
class __$FreezedPersonCopyWithImpl<$Res>
    implements _$FreezedPersonCopyWith<$Res> {
  __$FreezedPersonCopyWithImpl(this._self, this._then);

  final _FreezedPerson _self;
  final $Res Function(_FreezedPerson) _then;

  /// Create a copy of FreezedPerson
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? firstName = null,
    Object? middleName = null,
    Object? lastName = null,
    Object? age = null,
  }) {
    return _then(_FreezedPerson(
      firstName: null == firstName
          ? _self.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      middleName: null == middleName
          ? _self.middleName
          : middleName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _self.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      age: null == age
          ? _self.age
          : age // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
