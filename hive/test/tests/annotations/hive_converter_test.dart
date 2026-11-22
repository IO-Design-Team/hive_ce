import 'package:hive_ce/hive_ce.dart';
import 'package:test/test.dart';

class _UriConverter extends HiveConverter<Uri, String> {
  const _UriConverter();

  @override
  Uri fromHive(String value) => Uri.parse(value);

  @override
  String toHive(Uri value) => value.toString();
}

void main() {
  group('HiveConverter', () {
    test('converts values to and from Hive', () {
      const converter = _UriConverter();
      final uri = Uri.parse('https://example.com/path?q=1');
      final encoded = converter.toHive(uri);
      expect(encoded, 'https://example.com/path?q=1');
      expect(converter.fromHive(encoded), uri);
    });

    test('can be passed to GenerateAdapters', () {
      const annotation = GenerateAdapters(
        [],
        converters: [_UriConverter()],
      );
      expect(annotation.converters, hasLength(1));
      expect(annotation.converters.single, isA<HiveConverter<Uri, String>>());
    });
  });
}
