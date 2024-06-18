import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/adapters/ignored_type_adapter.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';

import '../common.dart';

class TestAdapter extends TypeAdapter<int> {
  TestAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  int read(BinaryReader reader) {
    return 5;
  }

  @override
  void write(BinaryWriter writer, obj) {}
}

class TestAdapter2 extends TypeAdapter<int> {
  @override
  int get typeId => 1;

  @override
  int read(BinaryReader reader) {
    return 5;
  }

  @override
  void write(BinaryWriter writer, obj) {}
}

class Parent {}

class Child extends Parent {}

class ParentAdapter extends TypeAdapter<Parent> {
  ParentAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  Parent read(BinaryReader reader) {
    return Parent();
  }

  @override
  void write(BinaryWriter writer, Parent obj) {}
}

class ChildAdapter extends TypeAdapter<Child> {
  ChildAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  Child read(BinaryReader reader) {
    return Child();
  }

  @override
  void write(BinaryWriter writer, Child obj) {}
}

void main() {
  group('TypeRegistryImpl', () {
    group('.registerAdapter()', () {
      test('register', () {
        final registry = TypeRegistryImpl();
        final adapter = TestAdapter();
        registry.registerAdapter(adapter);

        final resolved = registry.findAdapterForValue(123)!;
        expect(resolved.typeId, 32);
        expect(resolved.adapter, adapter);
      });

      test('unsupported typeId', () {
        final registry = TypeRegistryImpl();
        expect(() => registry.registerAdapter(TestAdapter(-1)),
            throwsHiveError('not allowed'),);
        expect(() => registry.registerAdapter(TestAdapter(224)),
            throwsHiveError('not allowed'),);
      });

      test('duplicate typeId', () {
        final registry = TypeRegistryImpl();
        registry.registerAdapter(TestAdapter());
        expect(() => registry.registerAdapter(TestAdapter()),
            throwsHiveError('already a TypeAdapter for typeId'),);
      });

      test('dynamic type', () {
        final registry = TypeRegistryImpl();
        registry.registerAdapter<dynamic>(TestAdapter());
      });
    });

    test('.findAdapterForTypeId()', () {
      final registry = TypeRegistryImpl();
      final adapter = TestAdapter();
      registry.registerAdapter(adapter);

      final resolvedAdapter = registry.findAdapterForTypeId(32)!;
      expect(resolvedAdapter.typeId, 32);
      expect(resolvedAdapter.adapter, adapter);
    });

    group('.findAdapterForValue()', () {
      test('finds adapter', () {
        final registry = TypeRegistryImpl();
        final adapter = TestAdapter();
        registry.registerAdapter(adapter);

        final resolvedAdapter = registry.findAdapterForValue(123)!;
        expect(resolvedAdapter.typeId, 32);
        expect(resolvedAdapter.adapter, adapter);
      });

      test('returns first matching adapter', () {
        final registry = TypeRegistryImpl();
        final adapter1 = TestAdapter(0);
        final adapter2 = TestAdapter(1);
        registry.registerAdapter(adapter1);
        registry.registerAdapter(adapter2);

        final resolvedAdapter = registry.findAdapterForValue(123)!;
        expect(resolvedAdapter.typeId, 32);
        expect(resolvedAdapter.adapter, adapter1);
      });

      test(
          'returns adapter if exact runtime type of value matches ignoring '
          'registration order', () {
        final registry = TypeRegistryImpl();
        final parentAdapter = ParentAdapter(0);
        final childAdapter = ChildAdapter(1);
        registry.registerAdapter(parentAdapter);
        registry.registerAdapter(childAdapter);

        final resolvedAdapter = registry.findAdapterForValue(Child());
        expect(resolvedAdapter?.typeId, 33);
        expect(resolvedAdapter?.adapter, childAdapter);
      });

      test('returns super type adapter for subtype', () {
        final registry = TypeRegistryImpl();
        final parentAdapter = ParentAdapter(0);
        registry.registerAdapter(parentAdapter);

        final resolvedAdapter = registry.findAdapterForValue(Child());
        expect(resolvedAdapter?.typeId, 32);
        expect(resolvedAdapter?.adapter, parentAdapter);
      });
    });

    test('.resetAdapters()', () {
      final registry = TypeRegistryImpl();
      final adapter = TestAdapter();
      registry.registerAdapter(adapter);

      registry.resetAdapters();
      expect(registry.findAdapterForValue(123), null);
    });

    group('.isAdapterRegistered()', () {
      test('returns false if adapter is not found', () {
        final registry = TypeRegistryImpl();

        expect(registry.isAdapterRegistered(0), false);
      });

      test('returns true if adapter is found', () {
        final registry = TypeRegistryImpl();
        final adapter = TestAdapter();
        registry.registerAdapter(adapter);

        expect(registry.isAdapterRegistered(0), true);
      });

      test('unsupported typeId', () {
        final registry = TypeRegistryImpl();
        expect(() => registry.isAdapterRegistered(-1),
            throwsHiveError('not allowed'),);
        expect(() => registry.isAdapterRegistered(224),
            throwsHiveError('not allowed'),);
      });
    });

    group('.ignoreTypeId()', () {
      test('registers IgnoredTypeAdapter', () {
        final registry = TypeRegistryImpl();
        registry.ignoreTypeId(0);
        final resolved = registry.findAdapterForTypeId(32)!;
        expect(resolved.adapter is IgnoredTypeAdapter, true);
      });

      test('duplicte typeId', () {
        final registry = TypeRegistryImpl();
        registry.registerAdapter(TestAdapter());
        expect(() => registry.ignoreTypeId(0),
            throwsHiveError('already a TypeAdapter for typeId'),);
      });
    });
  });
}
