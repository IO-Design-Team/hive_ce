import 'package:test/test.dart';

import 'test_utils.dart';

const directives = '''
import 'package:hive_ce/hive_ce.dart';
part 'hive_adapters.g.dart';
''';

const uriConverter = '''
class UriConverter implements HiveConverter<Uri, String> {
  const UriConverter();

  @override
  Uri fromHive(String hive) => Uri.parse(hive);

  @override
  String toHive(Uri object) => object.toString();
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

$uriConverter

@GenerateAdapters(
  [AdapterSpec<Website>()],
  converters: [UriConverter()],
)
class Website {
  const Website(this.url);

  final Uri url;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': const ContainsAll([
            'const UriConverter().fromHive(fields[0] as String)',
            'const UriConverter().toHive(obj.url)',
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

$uriConverter

@GenerateAdapters(
  [AdapterSpec<LinkList>()],
  converters: [UriConverter()],
)
class LinkList {
  const LinkList(this.urls);

  final List<Uri> urls;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': const ContainsAll([
            'const UriConverter().fromHive(e as String)',
            'const UriConverter().toHive(e)',
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

$uriConverter

@GenerateAdapters(
  [AdapterSpec<Website>()],
  converters: [UriConverter()],
)
class Website {
  const Website(this.url);

  final Uri? url;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': const ContainsAll([
            'fields[0] == null',
            'const UriConverter().fromHive(fields[0] as String)',
            'obj.url == null',
            'const UriConverter().toHive(obj.url as Uri)',
          ]),
        },
      );
    });
  });
}
