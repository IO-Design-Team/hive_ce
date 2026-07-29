import 'package:test/test.dart';

import 'test_utils.dart';

const directives = '''
import 'package:hive_ce/hive_ce.dart';
part 'hive_adapters.g.dart';
''';

const epochConverter = '''
class EpochDateTimeConverter implements HiveConverter<DateTime, int> {
  const EpochDateTimeConverter();

  @override
  DateTime fromHive(int hive) =>
      DateTime.fromMillisecondsSinceEpoch(hive);

  @override
  int toHive(DateTime object) => object.millisecondsSinceEpoch;
}
''';

void main() {
  group('HiveConverter', () {
    test('applies converter from GenerateAdapters.converters', () {
      expectGeneration(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$directives

$epochConverter

@GenerateAdapters(
  [AdapterSpec<Event>()],
  converters: [EpochDateTimeConverter()],
)
class Event {
  const Event(this.time);

  final DateTime time;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': const ContainsAll([
            'const EpochDateTimeConverter().fromHive(fields[0] as int)',
            'const EpochDateTimeConverter().toHive(obj.time)',
          ]),
        },
      );
    });

    test('applies generic converter with inferred type arguments', () {
      expectGeneration(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$directives

class WrappedList<T> {
  const WrappedList(this.values);
  final List<T> values;
}

class WrappedListConverter<T>
    implements HiveConverter<WrappedList<T>, List<T>> {
  const WrappedListConverter();

  @override
  WrappedList<T> fromHive(List<T> hive) => WrappedList(hive);

  @override
  List<T> toHive(WrappedList<T> object) => object.values;
}

@GenerateAdapters(
  [AdapterSpec<Box>()],
  converters: [WrappedListConverter()],
)
class Box {
  const Box(this.items);

  final WrappedList<String> items;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': const ContainsAll([
            'WrappedListConverter<String>().fromHive(fields[0] as List<String>)',
            'WrappedListConverter<String>().toHive(obj.items)',
          ]),
        },
      );
    });

    test('applies converter inside nested collections', () {
      expectGeneration(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$directives

$epochConverter

@GenerateAdapters(
  [AdapterSpec<Timeline>()],
  converters: [EpochDateTimeConverter()],
)
class Timeline {
  const Timeline(this.times);

  final List<DateTime> times;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': const ContainsAll([
            'const EpochDateTimeConverter().fromHive(e as int)',
            'const EpochDateTimeConverter().toHive(e)',
          ]),
        },
      );
    });

    test('handles nullable fields with non-nullable converter', () {
      expectGeneration(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$directives

$epochConverter

@GenerateAdapters(
  [AdapterSpec<Event>()],
  converters: [EpochDateTimeConverter()],
)
class Event {
  const Event(this.time);

  final DateTime? time;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': const ContainsAll([
            'fields[0] == null',
            'const EpochDateTimeConverter().fromHive(fields[0] as int)',
            'obj.time == null',
            'const EpochDateTimeConverter().toHive(obj.time as DateTime)',
          ]),
        },
      );
    });
  });
}
