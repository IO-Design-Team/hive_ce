import 'dart:math' as math;

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/adapters/big_int_adapter.dart';
import 'package:hive_ce/src/adapters/date_time_adapter.dart';
import 'package:hive_ce/src/adapters/duration_adapter.dart';
import 'package:hive_ce/src/adapters/ignored_type_adapter.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:meta/meta.dart';

/// Not part of public API
///
/// Needed to codegen the TypeRegistry mock
@visibleForTesting
@immutable
class ResolvedAdapter<T> {
  /// The [TypeAdapter] for type [T]
  final TypeAdapter adapter;

  /// The [adapter]'s [typeId]
  final int typeId;

  /// A wrapper for a [TypeAdapter] and its [typeId]
  const ResolvedAdapter(this.adapter, this.typeId);

  /// Checks if the given value's [runtimeType] is of type [T]
  bool matchesRuntimeType(dynamic value) => value.runtimeType == T;

  /// Checks if the given value is of type [T]
  bool matchesType(dynamic value) => value is T;

  /// Checks if the given type is of type [T]
  bool isForType<U>() => T == U;
}

class _NullTypeRegistry implements TypeRegistryImpl {
  const _NullTypeRegistry();

  @override
  Never get _typeAdapters => throw UnimplementedError();

  @override
  Never findAdapterForTypeId(int typeId) => throw UnimplementedError();

  @override
  Never findAdapterForValue(value) => throw UnimplementedError();

  @override
  ResolvedAdapter? findAdapterForType<T>() => throw UnimplementedError();

  @override
  Never ignoreTypeId<T>(int typeId) => throw UnimplementedError();

  @override
  Never isAdapterRegistered(int typeId, {bool internal = false}) =>
      throw UnimplementedError();

  @override
  Never registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) =>
      throw UnimplementedError();

  @override
  Never resetAdapters() => throw UnimplementedError();
}

/// Not part of public API
class TypeRegistryImpl implements TypeRegistry {
  /// Not part of public API
  static const TypeRegistryImpl nullImpl = _NullTypeRegistry();

  /// Max type ID is 1 byte long
  @visibleForTesting
  static final maxTypeId = math.pow(2, 8).toInt() - 1;

  /// Max extended type ID is 2 bytes long
  @visibleForTesting
  static final maxExtendedTypeId = math.pow(2, 16).toInt() - 1;

  /// Number of type IDs reserved for internal use
  @visibleForTesting
  static const reservedTypeIds = 32;

  /// Number of extended type IDs reserved for internal use
  @visibleForTesting
  static const reservedExtendedTypeIds = 64;

  /// Max type ID for internal adapters
  @visibleForTesting
  static const maxInternalTypeId =
      reservedTypeIds + reservedExtendedTypeIds - 1;

  /// Max type ID for external adapters
  @visibleForTesting
  static final maxExternalTypeId = maxTypeId - reservedTypeIds;

  /// Max extended type ID for external adapters
  @visibleForTesting
  static final maxExtendedExternalTypeId =
      maxExtendedTypeId - maxInternalTypeId - 1;

  final _typeAdapters = <int, ResolvedAdapter>{};

  /// Constructor
  TypeRegistryImpl() {
    _registerDefaultAdapters(this);
  }

  static void _registerDefaultAdapters(TypeRegistry registry) {
    registry.registerAdapter(DateTimeWithTimezoneAdapter(), internal: true);
    registry.registerAdapter(
      DateTimeAdapter<DateTimeWithoutTZ>(),
      internal: true,
    );
    registry.registerAdapter(BigIntAdapter(), internal: true);
    registry.registerAdapter(DurationAdapter(), internal: true);
  }

  /// Not part of public API
  ResolvedAdapter? findAdapterForValue(dynamic value) {
    ResolvedAdapter? match;
    for (final adapter in _typeAdapters.values) {
      if (adapter.matchesRuntimeType(value)) {
        return adapter;
      }
      if (adapter.matchesType(value) && match == null) {
        match = adapter;
      }
    }
    return match;
  }

  /// Not part of public API
  ResolvedAdapter? findAdapterForTypeId(int typeId) {
    return _typeAdapters[typeId];
  }

  /// Not part of public API
  ResolvedAdapter? findAdapterForType<T>() {
    for (final adapter in _typeAdapters.values) {
      if (adapter.isForType<T>()) {
        return adapter;
      }
    }
    return null;
  }

  @override
  void registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) {
    if (T == dynamic || T == Object) {
      debugPrint(
        'Registering type adapters for dynamic type is must be avoided, '
        'otherwise all the write requests to Hive will be handled by given '
        'adapter. Please explicitly provide adapter type on registerAdapter '
        'method to avoid this kind of issues. For example if you want to '
        'register MyTypeAdapter for MyType class you can call like this: '
        'registerAdapter<MyType>(MyTypeAdapter())',
      );
    }
    final typeId = calculateTypeId(adapter.typeId, internal: internal);
    if (!internal) {
      final oldAdapter = findAdapterForTypeId(typeId)?.adapter;
      if (oldAdapter != null) {
        if (override) {
          final oldAdapterType = oldAdapter.runtimeType;
          final newAdapterType = adapter.runtimeType;
          final typeId = adapter.typeId;
          debugPrint(
            'You are trying to override $oldAdapterType '
            'with $newAdapterType for typeId: $typeId. '
            'Please note that overriding adapters might '
            'cause weird errors. Try to avoid overriding adapters unless '
            'required.',
          );
        } else {
          throw HiveError('There is already a TypeAdapter for '
              'typeId ${typeId - reservedTypeIds}.');
        }
      }

      final existingTypeAdapter = findAdapterForType<T>()?.adapter;
      if (existingTypeAdapter != null) {
        final adapterTypeId = adapter.typeId;
        final existingAdapterTypeId = existingTypeAdapter.typeId;

        if (adapterTypeId != existingAdapterTypeId) {
          final adapterTypeString =
              '${adapter.runtimeType} (typeId $adapterTypeId)';
          final existingAdapterTypeString =
              '${existingTypeAdapter.runtimeType} (typeId $existingAdapterTypeId)';
          debugPrint(
            'WARNING: You are trying to register $adapterTypeString for type '
            '$T but there is already a TypeAdapter for this type: '
            '$existingAdapterTypeString. Note that $adapterTypeString will '
            'have no effect as $existingAdapterTypeString takes precedence. If '
            'you want to override the existing adapter, the typeIds must match.',
          );
        }
      }
    }

    _typeAdapters[typeId] = ResolvedAdapter<T>(adapter, typeId);
  }

  @override
  bool isAdapterRegistered(int typeId, {bool internal = false}) {
    typeId = calculateTypeId(typeId, internal: internal);
    return findAdapterForTypeId(typeId) != null;
  }

  /// TODO: Document this!
  void resetAdapters() {
    _typeAdapters.clear();
  }

  @override
  void ignoreTypeId<T>(int typeId) {
    registerAdapter(IgnoredTypeAdapter<T>(typeId));
  }

  /// Resolve the real type ID for the given [typeId]
  @visibleForTesting
  static int calculateTypeId(int typeId, {required bool internal}) {
    if (internal) {
      assert(typeId >= 0 && typeId <= maxInternalTypeId);

      if (typeId > reservedTypeIds - 1) {
        return typeId - reservedTypeIds + maxTypeId + 1;
      } else {
        return typeId;
      }
    } else {
      if (typeId < 0 || typeId > maxExtendedExternalTypeId) {
        throw HiveError('TypeId $typeId not allowed. Type ids must be in the '
            'range 0 <= typeId <= $maxExtendedExternalTypeId.');
      }

      if (typeId > maxTypeId - reservedTypeIds) {
        return typeId + reservedTypeIds + reservedExtendedTypeIds;
      } else {
        return typeId + reservedTypeIds;
      }
    }
  }
}
