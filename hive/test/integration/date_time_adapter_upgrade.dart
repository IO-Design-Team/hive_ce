import 'package:hive_ce/src/adapters/date_time_adapter.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';

import '../tests/common.dart';

void main() {
  group('upgrading DateTimeAdapter to DateTimeWithTimeZoneAdapter', () {
    group('TypeRegistry', () {
      late TypeRegistryImpl registry;

      setUp(() {
        registry = TypeRegistryImpl();
        registry.registerAdapter(DateTimeWithTimezoneAdapter(), internal: true);
        registry.registerAdapter(DateTimeAdapter(), internal: true);
      });

      tearDown(() {
        registry.resetAdapters();
      });

      test('uses DateTimeWithTimeZoneAdapter for writing new values', () {
        final result =
            expectNotNull(registry.findAdapterForValue(DateTime.timestamp()));
        expect(result.adapter, isA<DateTimeWithTimezoneAdapter>());
      });

      test('uses DateTimeWithTimeZoneAdapter for reading if typeId = 18', () {
        final result = expectNotNull(registry.findAdapterForTypeId(18));
        expect(result.adapter, isA<DateTimeWithTimezoneAdapter>());
      });

      test('uses DateTimeAdapter for reading if typeId = 16', () {
        final result = expectNotNull(registry.findAdapterForTypeId(16));
        expect(result.adapter, isA<DateTimeAdapter>());
      });
    });
  });
}
