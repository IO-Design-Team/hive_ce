import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/adapters/ignored_type_adapter.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';

import '../../util/print_utils.dart';
import '../common.dart';

class TestAdapter extends TypeAdapter<int> {
  const TestAdapter([this.typeId = 0]);

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
  const ParentAdapter([this.typeId = 0]);

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
  const ChildAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  Child read(BinaryReader reader) {
    return Child();
  }

  @override
  void write(BinaryWriter writer, Child obj) {}
}

class TestDurationAdapter extends TypeAdapter<Duration> {
  const TestDurationAdapter(this.typeId);

  @override
  final int typeId;

  @override
  Duration read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, obj) => throw UnimplementedError();
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
        expect(
          () => registry.registerAdapter(TestAdapter(-1)),
          throwsHiveError(['not allowed']),
        );
        expect(
          () => registry.registerAdapter(
            TestAdapter(TypeRegistryImpl.maxExtendedExternalTypeId + 1),
          ),
          throwsHiveError(['not allowed']),
        );
      });

      test('duplicate typeId', () {
        final registry = TypeRegistryImpl();
        registry.registerAdapter(TestAdapter());
        expect(
          () => registry.registerAdapter(TestAdapter()),
          throwsHiveError(['already a TypeAdapter for typeId']),
        );
      });

      test('dynamic type', () {
        final registry = TypeRegistryImpl();
        registry.registerAdapter<dynamic>(TestAdapter());
      });

      group('override', () {
        test('by typeId', () async {
          final registry = TypeRegistryImpl();
          registry.registerAdapter(TestAdapter());

          final output = await captureOutput(
            () => registry.registerAdapter(TestAdapter(), override: true),
          ).toList();
          expect(
            output,
            contains(contains('You are trying to override TestAdapter')),
          );
          expect(
            output,
            isNot(
              contains(
                contains('WARNING: You are trying to register TestAdapter'),
              ),
            ),
          );
        });

        group('by type', () {
          test('external', () async {
            final registry = TypeRegistryImpl();
            registry.registerAdapter(TestAdapter(100));

            final foundAdapter1 = registry.findAdapterForType<int>();
            expect(foundAdapter1!.adapter.typeId, 100);

            final output = await captureOutput(
              () => registry.registerAdapter(TestAdapter(200), override: true),
            ).toList();
            expect(
              output,
              contains(contains('Removed existing adapter TestAdapter')),
            );

            final foundAdapter2 = registry.findAdapterForType<int>();
            expect(foundAdapter2!.adapter.typeId, 200);
          });

          test('internal', () async {
            final registry = TypeRegistryImpl();

            final foundAdapter1 = registry.findAdapterForType<Duration>();
            expect(foundAdapter1!.adapter.typeId, 20);

            final output = await captureOutput(
              () => registry.registerAdapter(
                TestDurationAdapter(60),
                override: true,
              ),
            ).toList();
            expect(
              output,
              contains(
                contains(
                  'Removed existing adapter DurationAdapter (typeId 20) for '
                  'type Duration and replaced with TestDurationAdapter (typeId 60).',
                ),
              ),
            );

            final foundAdapter2 = registry.findAdapterForType<Duration>();
            expect(foundAdapter2!.adapter.typeId, 60);
          });
        });
      });

      test('adapter with same type warning', () async {
        final registry = TypeRegistryImpl();
        registry.registerAdapter(TestAdapter());

        final output =
            await captureOutput(() => registry.registerAdapter(TestAdapter(1)))
                .toList();
        expect(
          output,
          contains(contains('WARNING: You are trying to register TestAdapter')),
        );
      });

      group('with typeId extension', () {
        test('external', () {
          final registry = TypeRegistryImpl();
          registry.registerAdapter(TestAdapter(224));
          final resolved = registry.findAdapterForValue(123)!;
          expect(resolved.typeId, 320);
        });

        test('internal', () {
          final registry = TypeRegistryImpl();
          registry.registerAdapter(TestAdapter(32), internal: true);
          final resolved = registry.findAdapterForValue(123)!;
          expect(resolved.typeId, 256);
        });
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
        expect(
          () => registry.isAdapterRegistered(-1),
          throwsHiveError(['not allowed']),
        );
        expect(
          () => registry.isAdapterRegistered(
            TypeRegistryImpl.maxExtendedExternalTypeId + 1,
          ),
          throwsHiveError(['not allowed']),
        );
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
        expect(
          () => registry.ignoreTypeId(0),
          throwsHiveError(['already a TypeAdapter for typeId']),
        );
      });
    });

    group('type id', () {
      test('constants', () {
        expect(TypeRegistryImpl.maxTypeId, 255);
        expect(TypeRegistryImpl.maxExtendedTypeId, 65535);
        expect(TypeRegistryImpl.maxInternalTypeId, 95);
        expect(TypeRegistryImpl.maxExternalTypeId, 223);
        expect(TypeRegistryImpl.maxExtendedExternalTypeId, 65439);
      });

      test('calculations', () {
        // internal
        expect(TypeRegistryImpl.calculateTypeId(0, internal: true), 0);
        expect(TypeRegistryImpl.calculateTypeId(31, internal: true), 31);
        expect(TypeRegistryImpl.calculateTypeId(32, internal: true), 256);
        expect(TypeRegistryImpl.calculateTypeId(95, internal: true), 319);
        expect(
          () => TypeRegistryImpl.calculateTypeId(96, internal: true),
          throwsA(isA<AssertionError>()),
        );

        // external
        expect(TypeRegistryImpl.calculateTypeId(0, internal: false), 32);
        expect(TypeRegistryImpl.calculateTypeId(223, internal: false), 255);
        expect(TypeRegistryImpl.calculateTypeId(224, internal: false), 320);
        expect(TypeRegistryImpl.calculateTypeId(65439, internal: false), 65535);
        expect(
          () => TypeRegistryImpl.calculateTypeId(65440, internal: false),
          throwsHiveError(),
        );
      });

      test('isInternalTypeId', () {
        expect(TypeRegistryImpl.isInternalTypeId(0), true);
        expect(TypeRegistryImpl.isInternalTypeId(31), true);
        expect(TypeRegistryImpl.isInternalTypeId(32), false);
        expect(TypeRegistryImpl.isInternalTypeId(255), false);
        expect(TypeRegistryImpl.isInternalTypeId(256), true);
        expect(TypeRegistryImpl.isInternalTypeId(319), true);
        expect(TypeRegistryImpl.isInternalTypeId(320), false);
      });
    });
  });
}
