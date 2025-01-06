import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/adapters/ignored_type_adapter.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:meta/meta.dart';

/// Not part of public API
///
/// Needed to codegen the TypeRegistry mock
@visibleForTesting
class ResolvedAdapter<T> {
  /// The [TypeAdapter] for type [T]
  final TypeAdapter adapter;

  /// The [adapter]'s [typeId]
  final int typeId;

  /// A wrapper for a [TypeAdapter] and its [typeId]
  ResolvedAdapter(this.adapter, this.typeId);

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

  /// Not part of public API
  @visibleForTesting
  static const reservedTypeIds = 32;

  final _typeAdapters = <int, ResolvedAdapter>{};

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
    var typeId = adapter.typeId;
    if (!internal) {
      if (typeId < 0 || typeId > 223) {
        throw HiveError('TypeId $typeId not allowed. Type ids must be in the '
            'range 0 <= typeId <= 223.');
      }
      typeId = typeId + reservedTypeIds;

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

      final adapterForSameType = findAdapterForType<T>()?.adapter;
      if (adapterForSameType != null) {
        final adapterType = adapter.runtimeType;
        final adapterTypeId = adapter.typeId;
        final existingAdapterType = adapterForSameType.runtimeType;
        final existingAdapterTypeId = adapterForSameType.typeId;

        if (adapterTypeId != existingAdapterTypeId) {
          debugPrint(
            'WARNING: You are trying to register $adapterType '
            '(typeId $adapterTypeId) for type $T but there is already a '
            'TypeAdapter for this type: $existingAdapterType '
            '(typeId $existingAdapterTypeId). Note that $adapterType will have '
            'no effect as $existingAdapterType takes precedence. If you want to '
            'override the existing adapter, the typeIds must match.',
          );
        }
      }
    }

    final resolved = ResolvedAdapter<T>(adapter, typeId);
    _typeAdapters[typeId] = resolved;
  }

  @override
  bool isAdapterRegistered(int typeId, {bool internal = false}) {
    if (!internal) {
      if (typeId < 0 || typeId > 223) {
        throw HiveError('TypeId $typeId not allowed.');
      }

      typeId = typeId + reservedTypeIds;
    }

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
}
