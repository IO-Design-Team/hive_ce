import 'package:test/test.dart';

import 'test_utils.dart';

const _adaptersPart = 'lib/hive/hive_adapters.hive_adapters_generator.g.part';

const _directives = '''
import 'package:hive_ce/hive_ce.dart';
part 'hive_adapters.g.dart';''';

const _strictAnalysisOptions = '''
analyzer:
  language:
    strict-casts: true
    strict-inference: true
linter:
  rules:
    - unnecessary_const
    - unnecessary_null_checks
    - avoid_dynamic_calls
''';

const _uriConverter = '''
class UriConverter extends HiveConverter<Uri, String> {
  const UriConverter();

  @override
  Uri fromHive(String value) => Uri.parse(value);

  @override
  String toHive(Uri value) => value.toString();
}''';

const _unmodifiableListViewConverter = '''
class UnmodifiableListViewConverter<E>
    extends HiveConverter<UnmodifiableListView<E>, List<E>> {
  const UnmodifiableListViewConverter();

  @override
  UnmodifiableListView<E> fromHive(List<E> value) =>
      UnmodifiableListView(value);

  @override
  List<E> toHive(UnmodifiableListView<E> value) => value.toList();
}''';

const _unmodifiableMapViewConverter = '''
class UnmodifiableMapViewConverter<K, V>
    extends HiveConverter<UnmodifiableMapView<K, V>, Map<K, V>> {
  const UnmodifiableMapViewConverter();

  @override
  UnmodifiableMapView<K, V> fromHive(Map<K, V> value) =>
      UnmodifiableMapView(value);

  @override
  Map<K, V> toHive(UnmodifiableMapView<K, V> value) => value;
}''';

Matcher _calls(String expr, String method) =>
    matches(RegExp('${RegExp.escape(expr)}\\s*\\.$method\\('));

Future<void> _roundTrip({
  required Map<String, String> input,
  required String body,
  List<String> imports = const [],
  Map<String, Object> output = const {},
}) {
  final importLines = [
    "import 'dart:io';",
    ...imports,
    "import 'package:hive_ce/hive_ce.dart';",
    "import 'package:hive_ce_generator_test/hive/hive_registrar.g.dart';",
  ].join('\n');

  return expectRoundTrip(
    input: input,
    output: output,
    script: '''
$importLines

Future<void> main() async {
  final dir = Directory.systemTemp.createTempSync('hive_converter_test_');
  try {
    Hive.init(dir.path);
    Hive.registerAdapters();
    $body
  } finally {
    dir.deleteSync(recursive: true);
  }
}
''',
  );
}

void main() {
  group('converters', () {
    test('non-generic converter with nullability, defaults, and setter',
        () async {
      await _roundTrip(
        input: {
          ...pubspec(),
          'analysis_options.yaml': _strictAnalysisOptions,
          'lib/hive/hive_adapters.dart': '''
$_directives

$_uriConverter

class Tag {
  final String label;
  const Tag(this.label);

  @override
  bool operator ==(Object other) => other is Tag && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

class TagConverter implements HiveConverter<Tag, String> {
  const TagConverter();

  @override
  Tag fromHive(String value) => Tag(value);

  @override
  String toHive(Tag value) => value.label;
}

@GenerateAdapters(
  [AdapterSpec<Model>()],
  converters: [UriConverter(), TagConverter()],
)
class Model {
  Model({
    required this.uri,
    this.nullableUri,
    Tag? defaultedTag,
  }) : defaultedTag = defaultedTag ?? const Tag('default');

  final Uri uri;
  final Uri? nullableUri;
  final Tag defaultedTag;
  Tag? mutableTag;
}
''',
        },
        imports: [
          "import 'package:hive_ce_generator_test/hive/hive_adapters.dart';",
        ],
        output: {
          _adaptersPart: allOf([
            contains('const UriConverter().fromHive(fields[0] as String)'),
            contains(
              'fields[1] == null\n'
              '          ? null\n'
              '          : const UriConverter().fromHive(fields[1] as String)',
            ),
            contains('const TagConverter().fromHive(fields[2] as String)'),
            contains('..mutableTag ='),
            contains('..write(const UriConverter().toHive(obj.uri))'),
            contains(
              'switch (obj.nullableUri) {\n'
              '        final value? => const UriConverter().toHive(value),\n'
              '        null => null\n'
              '      }',
            ),
          ]),
        },
        body: '''
    final box = await Hive.openBox<Model>('models');
    final m1 = Model(
      uri: Uri.parse('https://example.com/a?b=1'),
      nullableUri: Uri.parse('https://example.org/b'),
      defaultedTag: const Tag('custom'),
    )..mutableTag = const Tag('mut');
    final m2 = Model(uri: Uri.parse('https://example.net'), nullableUri: null);

    await box.put('m1', m1);
    await box.put('m2', m2);
    await box.close();

    final reopened = await Hive.openBox<Model>('models');
    final r1 = reopened.get('m1')!;
    final r2 = reopened.get('m2')!;

    if (r1.uri != m1.uri) throw StateError('m1.uri mismatch: \${r1.uri}');
    if (r1.nullableUri != m1.nullableUri) {
      throw StateError('m1.nullableUri mismatch');
    }
    if (r1.defaultedTag != const Tag('custom')) {
      throw StateError('m1.defaultedTag mismatch');
    }
    if (r1.mutableTag != const Tag('mut')) {
      throw StateError('m1.mutableTag mismatch');
    }
    if (r2.uri != m2.uri) throw StateError('m2.uri mismatch');
    if (r2.nullableUri != null) throw StateError('m2.nullableUri should be null');
    if (r2.defaultedTag != const Tag('default')) {
      throw StateError('m2.defaultedTag mismatch');
    }
    if (r2.mutableTag != null) throw StateError('m2.mutableTag should be null');
    await reopened.close();
''',
      );
    });

    test('default value on nullable field does not emit duplicate null check',
        () async {
      await expectGeneration(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$_directives

$_uriConverter

const _fallback = Uri(scheme: 'https', host: 'default.test');

@GenerateAdapters([AdapterSpec<Model>()], converters: [UriConverter()])
class Model {
  const Model({this.uri = _fallback});

  final Uri? uri;
}
''',
        },
        output: {
          _adaptersPart: allOf(
            contains(
              'fields[0] == null\n'
              '          ? _fallback\n'
              '          : const UriConverter().fromHive(fields[0] as String)',
            ),
            isNot(contains('? null :')),
          ),
        },
      );
    });

    test('collections containing converted types', () async {
      await _roundTrip(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$_directives

$_uriConverter

@GenerateAdapters([AdapterSpec<CollectionsModel>()], converters: [UriConverter()])
class CollectionsModel {
  const CollectionsModel({
    required this.uris,
    required this.nullableElementUris,
    required this.nullableUris,
    required this.uriSet,
    required this.nullableUriSet,
    required this.uriIterable,
    required this.uriMap,
    required this.nestedListMap,
  });

  final List<Uri> uris;
  final List<Uri?> nullableElementUris;
  final List<Uri>? nullableUris;
  final Set<Uri> uriSet;
  final Set<Uri?>? nullableUriSet;
  final Iterable<Uri> uriIterable;
  final Map<Uri, Set<Uri?>>? uriMap;
  final List<Map<String, Uri>?> nestedListMap;
}
''',
        },
        imports: [
          "import 'package:hive_ce_generator_test/hive/hive_adapters.dart';",
        ],
        body: '''
    final box = await Hive.openBox<CollectionsModel>('models');
    final u1 = Uri.parse('https://a.test/1');
    final u2 = Uri.parse('https://b.test/2');

    await box.put(
      'full',
      CollectionsModel(
        uris: [u1, u2],
        nullableElementUris: [u1, null, u2],
        nullableUris: [u2],
        uriSet: {u1, u2},
        nullableUriSet: {u1, null},
        uriIterable: [u1],
        uriMap: {u1: {u2, null}},
        nestedListMap: [{'k': u1}, null],
      ),
    );
    await box.put(
      'nulls',
      const CollectionsModel(
        uris: [],
        nullableElementUris: [],
        nullableUris: null,
        uriSet: {},
        nullableUriSet: null,
        uriIterable: [],
        uriMap: null,
        nestedListMap: [null],
      ),
    );
    await box.close();

    final reopened = await Hive.openBox<CollectionsModel>('models');
    final rf = reopened.get('full')!;
    final rn = reopened.get('nulls')!;

    if (rf.uris.length != 2 || rf.uris[0] != u1 || rf.uris[1] != u2) {
      throw StateError('uris mismatch');
    }
    if (rf.nullableElementUris[1] != null || rf.nullableElementUris[0] != u1) {
      throw StateError('nullableElementUris mismatch');
    }
    if (rf.nullableUris?.single != u2) throw StateError('nullableUris mismatch');
    if (!rf.uriSet.containsAll([u1, u2])) throw StateError('uriSet mismatch');
    if (!rf.nullableUriSet!.contains(null) || !rf.nullableUriSet!.contains(u1)) {
      throw StateError('nullableUriSet mismatch');
    }
    if (rf.uriIterable.single != u1) throw StateError('uriIterable mismatch');
    if (!rf.uriMap![u1]!.contains(null) || !rf.uriMap![u1]!.contains(u2)) {
      throw StateError('uriMap mismatch');
    }
    if (rf.nestedListMap[0]!['k'] != u1 || rf.nestedListMap[1] != null) {
      throw StateError('nestedListMap mismatch');
    }
    if (rn.nullableUris != null || rn.nullableUriSet != null || rn.uriMap != null) {
      throw StateError('nulls mismatch');
    }
    await reopened.close();
''',
      );
    });

    test('generic converters: unparameterized, bounded, concrete, precedence',
        () async {
      await _roundTrip(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
import 'dart:collection';
$_directives

$_unmodifiableListViewConverter

class SpecialStringListConverter
    extends HiveConverter<UnmodifiableListView<String>, List<String>> {
  const SpecialStringListConverter();

  @override
  UnmodifiableListView<String> fromHive(List<String> value) =>
      UnmodifiableListView([...value, 'fromSpecial']);

  @override
  List<String> toHive(UnmodifiableListView<String> value) => value.toList();
}

class BoxedValue<T> {
  final T value;
  const BoxedValue(this.value);
}

class NumBoxConverter<T extends num> extends HiveConverter<BoxedValue<T>, T> {
  const NumBoxConverter();

  @override
  BoxedValue<T> fromHive(T value) => BoxedValue(value);

  @override
  T toHive(BoxedValue<T> value) => value.value;
}

class StringBoxConverter extends HiveConverter<BoxedValue<String>, String> {
  const StringBoxConverter();

  @override
  BoxedValue<String> fromHive(String value) => BoxedValue(value);

  @override
  String toHive(BoxedValue<String> value) => value.value;
}

$_unmodifiableMapViewConverter

@GenerateAdapters(
  [AdapterSpec<GenericModel>()],
  converters: [
    UnmodifiableListViewConverter(),
    SpecialStringListConverter(),
    NumBoxConverter(),
    StringBoxConverter(),
    UnmodifiableMapViewConverter(),
  ],
)
class GenericModel {
  const GenericModel({
    required this.strings,
    required this.ints,
    required this.nullableIntElements,
    this.nullableView,
    required this.numIntBox,
    required this.numDoubleBox,
    required this.stringBox,
    required this.mapView,
  });

  final UnmodifiableListView<String> strings;
  final UnmodifiableListView<int> ints;
  final UnmodifiableListView<int?> nullableIntElements;
  final UnmodifiableListView<int>? nullableView;
  final BoxedValue<int> numIntBox;
  final BoxedValue<double> numDoubleBox;
  final BoxedValue<String> stringBox;
  final UnmodifiableMapView<String, int> mapView;
}
''',
        },
        imports: [
          "import 'dart:collection';",
          "import 'package:hive_ce_generator_test/hive/hive_adapters.dart';",
        ],
        output: {
          _adaptersPart: allOf([
            _calls('const SpecialStringListConverter()', 'fromHive'),
            _calls('const UnmodifiableListViewConverter<int>()', 'fromHive'),
            _calls('const UnmodifiableListViewConverter<int?>()', 'fromHive'),
            _calls('const NumBoxConverter<int>()', 'fromHive'),
            _calls('const NumBoxConverter<double>()', 'fromHive'),
            _calls('const StringBoxConverter()', 'fromHive'),
            _calls(
              'const UnmodifiableMapViewConverter<String, int>()',
              'fromHive',
            ),
          ]),
        },
        body: '''
    final box = await Hive.openBox<GenericModel>('models');
    await box.put(
      'm',
      GenericModel(
        strings: UnmodifiableListView(['a']),
        ints: UnmodifiableListView([1, 2]),
        nullableIntElements: UnmodifiableListView([1, null]),
        nullableView: UnmodifiableListView([3]),
        numIntBox: const BoxedValue(7),
        numDoubleBox: const BoxedValue(2.5),
        stringBox: const BoxedValue('hi'),
        mapView: UnmodifiableMapView({'x': 10}),
      ),
    );
    await box.close();

    final reopened = await Hive.openBox<GenericModel>('models');
    final r = reopened.get('m')!;

    if (r.strings.toList().join(',') != 'a,fromSpecial') {
      throw StateError('concrete precedence failed: \${r.strings}');
    }
    if (r.ints.toList().toString() != '[1, 2]') {
      throw StateError('ints mismatch');
    }
    if (r.nullableIntElements.toList().toString() != '[1, null]') {
      throw StateError('nullableIntElements mismatch');
    }
    if (r.nullableView?.single != 3) throw StateError('nullableView mismatch');
    if (r.numIntBox.value != 7) throw StateError('numIntBox mismatch');
    if (r.numDoubleBox.value != 2.5) throw StateError('numDoubleBox mismatch');
    if (r.stringBox.value != 'hi') throw StateError('stringBox mismatch');
    if (r.mapView['x'] != 10) throw StateError('mapView mismatch');
    await reopened.close();
''',
      );
    });

    test('concrete generic converter ignores non-matching element types',
        () async {
      await expectGeneration(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
import 'dart:collection';
$_directives

$_unmodifiableListViewConverter

@GenerateAdapters(
  [AdapterSpec<Model>()],
  converters: [UnmodifiableListViewConverter<String>()],
)
class Model {
  const Model(this.strings, this.ints);
  final UnmodifiableListView<String> strings;
  final List<int> ints;
}
''',
        },
        output: {
          _adaptersPart: allOf(
            _calls('const UnmodifiableListViewConverter<String>()', 'fromHive'),
            isNot(contains('UnmodifiableListViewConverter<int>')),
          ),
        },
      );
    });

    test('bound mismatch skips generic converter', () async {
      await expectGeneration(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$_directives

class NumBox<T> {
  final T value;
  const NumBox(this.value);
}

class NumBoxConverter<T extends num> extends HiveConverter<NumBox<T>, T> {
  const NumBoxConverter();

  @override
  NumBox<T> fromHive(T value) => NumBox(value);

  @override
  T toHive(NumBox<T> value) => value.value;
}

@GenerateAdapters([AdapterSpec<Model>()], converters: [NumBoxConverter()])
class Model {
  const Model(this.numBox, this.nullableNumBox);
  final NumBox<int> numBox;
  final NumBox<int?> nullableNumBox;
}
''',
        },
        output: {
          _adaptersPart: allOf(
            _calls('const NumBoxConverter<int>()', 'fromHive'),
            isNot(contains('NumBoxConverter<int?>')),
          ),
        },
      );
    });

    test('chaining and composition across multiple converters', () async {
      await _roundTrip(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
import 'dart:collection';
$_directives

$_uriConverter

$_unmodifiableListViewConverter

$_unmodifiableMapViewConverter

@GenerateAdapters(
  [AdapterSpec<ChainedModel>()],
  converters: [
    UriConverter(),
    UnmodifiableListViewConverter(),
    UnmodifiableMapViewConverter(),
  ],
)
class ChainedModel {
  const ChainedModel({
    required this.uriView,
    required this.nestedViews,
    required this.complexMap,
  });

  final UnmodifiableListView<Uri> uriView;
  final UnmodifiableListView<UnmodifiableListView<String>> nestedViews;
  final UnmodifiableMapView<Uri, UnmodifiableListView<Uri?>>? complexMap;
}
''',
        },
        imports: [
          "import 'dart:collection';",
          "import 'package:hive_ce_generator_test/hive/hive_adapters.dart';",
        ],
        body: '''
    final box = await Hive.openBox<ChainedModel>('models');
    final u1 = Uri.parse('https://a.test');
    final u2 = Uri.parse('https://b.test');
    await box.put(
      'm',
      ChainedModel(
        uriView: UnmodifiableListView([u1, u2]),
        nestedViews: UnmodifiableListView([
          UnmodifiableListView(['x', 'y']),
        ]),
        complexMap: UnmodifiableMapView({
          u1: UnmodifiableListView([u2, null]),
        }),
      ),
    );
    await box.close();

    final reopened = await Hive.openBox<ChainedModel>('models');
    final r = reopened.get('m')!;

    if (r.uriView.length != 2 || r.uriView[0] != u1 || r.uriView[1] != u2) {
      throw StateError('uriView mismatch');
    }
    if (r.nestedViews.single.toList().join(',') != 'x,y') {
      throw StateError('nestedViews mismatch');
    }
    if (r.complexMap![u1]![0] != u2 || r.complexMap![u1]![1] != null) {
      throw StateError('complexMap mismatch');
    }
    await reopened.close();
''',
      );
    });

    test('nullable, identity, int, and dynamic stored types', () async {
      await _roundTrip(
        input: {
          ...pubspec(),
          'analysis_options.yaml': _strictAnalysisOptions,
          'lib/hive/hive_adapters.dart': '''
$_directives

$_uriConverter

class NullableUriConverter extends HiveConverter<Uri?, String> {
  const NullableUriConverter();

  @override
  Uri? fromHive(String value) => value.isEmpty ? null : Uri.parse(value);

  @override
  String toHive(Uri? value) => value?.toString() ?? '';
}

class NullableString {
  final String? value;
  const NullableString(this.value);

  @override
  bool operator ==(Object other) =>
      other is NullableString && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class NullableStringConverter extends HiveConverter<NullableString?, String?> {
  const NullableStringConverter();

  @override
  NullableString? fromHive(String? value) =>
      value == null ? const NullableString('fromNull') : NullableString(value);

  @override
  String? toHive(NullableString? value) => value?.value;
}

class UtcDateTimeConverter extends HiveConverter<DateTime, DateTime> {
  const UtcDateTimeConverter();

  @override
  DateTime fromHive(DateTime value) => value.toUtc();

  @override
  DateTime toHive(DateTime value) => value.toUtc();
}

class EpochWrapper {
  final int millis;
  const EpochWrapper(this.millis);

  @override
  bool operator ==(Object other) =>
      other is EpochWrapper && other.millis == millis;

  @override
  int get hashCode => millis.hashCode;
}

class EpochConverter extends HiveConverter<EpochWrapper, int> {
  const EpochConverter();

  @override
  EpochWrapper fromHive(int value) => EpochWrapper(value);

  @override
  int toHive(EpochWrapper value) => value.millis;
}

class DynWrapper {
  final Object? payload;
  const DynWrapper(this.payload);

  @override
  bool operator ==(Object other) =>
      other is DynWrapper && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;
}

class DynConverter extends HiveConverter<DynWrapper, dynamic> {
  const DynConverter();

  @override
  DynWrapper fromHive(dynamic value) => DynWrapper(value);

  @override
  dynamic toHive(DynWrapper value) => value.payload;
}

@GenerateAdapters(
  [AdapterSpec<EdgeModel>()],
  converters: [
    UriConverter(),
    NullableUriConverter(),
    NullableStringConverter(),
    UtcDateTimeConverter(),
    EpochConverter(),
    DynConverter(),
  ],
)
class EdgeModel {
  const EdgeModel({
    required this.requiredUri,
    required this.nullableUri,
    required this.nullableStr,
    required this.utcDate,
    required this.epoch,
    required this.dyn,
  });

  final Uri requiredUri;
  final Uri? nullableUri;
  final NullableString? nullableStr;
  final DateTime utcDate;
  final EpochWrapper epoch;
  final DynWrapper dyn;
}
''',
        },
        imports: [
          "import 'package:hive_ce_generator_test/hive/hive_adapters.dart';",
        ],
        output: {
          _adaptersPart: allOf([
            contains('const UriConverter().fromHive(fields[0] as String)'),
            contains(
              'const NullableUriConverter().fromHive(fields[1] as String)',
            ),
            contains('const NullableUriConverter().toHive(obj.nullableUri)'),
            contains(
              'const NullableStringConverter().fromHive(fields[2] as String?)',
            ),
            contains(
              'const UtcDateTimeConverter().fromHive(fields[3] as DateTime)',
            ),
            contains(
              'const EpochConverter().fromHive((fields[4] as num).toInt())',
            ),
            contains('const DynConverter().fromHive(fields[5])'),
            isNot(contains('as dynamic')),
          ]),
        },
        body: '''
    final box = await Hive.openBox<EdgeModel>('models');
    final localTime = DateTime(2026, 6, 1, 12, 0);
    final model = EdgeModel(
      requiredUri: Uri.parse('https://req.test'),
      nullableUri: null,
      nullableStr: null,
      utcDate: localTime,
      epoch: const EpochWrapper(123456),
      dyn: const DynWrapper('hello'),
    );

    await box.put('m', model);
    await box.close();

    final reopened = await Hive.openBox<EdgeModel>('models');
    final r = reopened.get('m')!;

    if (r.requiredUri != model.requiredUri) {
      throw StateError('requiredUri mismatch');
    }
    if (r.nullableUri != null) throw StateError('nullableUri mismatch');
    if (r.nullableStr != const NullableString('fromNull')) {
      throw StateError('nullableStr mismatch: \${r.nullableStr}');
    }
    if (!r.utcDate.isUtc || r.utcDate != localTime.toUtc()) {
      throw StateError('utcDate mismatch');
    }
    if (r.epoch != const EpochWrapper(123456)) {
      throw StateError('epoch mismatch');
    }
    if (r.dyn != const DynWrapper('hello')) throw StateError('dyn mismatch');
    await reopened.close();
''',
      );
    });

    test(
        'parameterized constructors, named constructors, static/top-level consts, and prefixed imports',
        () async {
      await _roundTrip(
        input: {
          ...pubspec(),
          'lib/types/domain.dart': '''
class CustomId {
  final String value;
  const CustomId(this.value);

  @override
  bool operator ==(Object other) => other is CustomId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class Wrapper<T> {
  final T item;
  const Wrapper(this.item);
}

class ModelInOtherFile {
  final DateTime createdAt;
  final CustomId id;
  final Wrapper<CustomId> wrappedId;
  final String note;
  final int count;

  const ModelInOtherFile({
    required this.createdAt,
    required this.id,
    required this.wrappedId,
    required this.note,
    required this.count,
  });
}
''',
          'lib/converters/converters.dart': '''
import 'package:hive_ce/hive_ce.dart';
import '../types/domain.dart';

enum Mode { upper, lower }

class DateTimeConverter extends HiveConverter<DateTime, int> {
  final bool isUtc;
  const DateTimeConverter.utc() : isUtc = true;

  @override
  DateTime fromHive(int value) =>
      DateTime.fromMillisecondsSinceEpoch(value, isUtc: isUtc);

  @override
  int toHive(DateTime value) => value.millisecondsSinceEpoch;
}

class PrefixedStringConverter extends HiveConverter<String, String> {
  final String prefix;
  final Mode mode;

  const PrefixedStringConverter(this.prefix, {this.mode = Mode.lower});

  @override
  String fromHive(String value) => value;

  @override
  String toHive(String value) => value;
}

class CustomIdConverter extends HiveConverter<CustomId, String> {
  const CustomIdConverter._();
  static const instance = CustomIdConverter._();

  @override
  CustomId fromHive(String value) => CustomId(value);

  @override
  String toHive(CustomId value) => value.value;
}

class IntConverter extends HiveConverter<int, int> {
  const IntConverter._();

  @override
  int fromHive(int value) => value;

  @override
  int toHive(int value) => value;
}

const topLevelIntConverter = IntConverter._();

class WrapperConverter<T> extends HiveConverter<Wrapper<T>, T> {
  final String label;
  const WrapperConverter(this.label);

  @override
  Wrapper<T> fromHive(T value) => Wrapper(value);

  @override
  T toHive(Wrapper<T> value) => value.item;
}
''',
          'lib/hive/hive_adapters.dart': '''
import 'package:hive_ce/hive_ce.dart';
import '../converters/converters.dart' as conv;
import '../types/domain.dart' as dom;

@GenerateAdapters(
  [AdapterSpec<dom.ModelInOtherFile>()],
  converters: [
    conv.DateTimeConverter.utc(),
    conv.PrefixedStringConverter('tag:', mode: conv.Mode.upper),
    conv.CustomIdConverter.instance,
    conv.topLevelIntConverter,
    conv.WrapperConverter('w'),
  ],
)
part 'hive_adapters.g.dart';
''',
        },
        imports: ["import 'package:hive_ce_generator_test/types/domain.dart';"],
        output: {
          _adaptersPart: allOf([
            contains('TypeAdapter<dom.ModelInOtherFile>'),
            _calls('const conv.DateTimeConverter.utc()', 'fromHive'),
            _calls(
              "const conv.PrefixedStringConverter('tag:', mode: conv.Mode.upper)",
              'fromHive',
            ),
            _calls('conv.CustomIdConverter.instance', 'fromHive'),
            _calls('conv.topLevelIntConverter', 'fromHive'),
            _calls(
              "const conv.WrapperConverter<dom.CustomId>('w')",
              'fromHive',
            ),
          ]),
        },
        body: '''
    final box = await Hive.openBox<ModelInOtherFile>('models');
    final model = ModelInOtherFile(
      createdAt: DateTime.utc(2026, 1, 2, 3, 4),
      id: const CustomId('abc'),
      wrappedId: const Wrapper(CustomId('xyz')),
      note: 'hello',
      count: 42,
    );

    await box.put('m', model);
    await box.close();

    final reopened = await Hive.openBox<ModelInOtherFile>('models');
    final r = reopened.get('m')!;

    if (!r.createdAt.isUtc || r.createdAt != model.createdAt) {
      throw StateError('createdAt mismatch');
    }
    if (r.id != model.id) throw StateError('id mismatch');
    if (r.wrappedId.item != const CustomId('xyz')) {
      throw StateError('wrappedId mismatch');
    }
    if (r.note != 'hello' || r.count != 42) {
      throw StateError('note/count mismatch');
    }
    await reopened.close();
''',
      );
    });

    test('private converter in same library succeeds, across libraries throws',
        () async {
      await _roundTrip(
        input: {
          ...pubspec(),
          'lib/hive/hive_adapters.dart': '''
$_directives

class _LocalConverter extends HiveConverter<Uri, String> {
  const _LocalConverter();

  @override
  Uri fromHive(String value) => Uri.parse(value);

  @override
  String toHive(Uri value) => value.toString();
}

@GenerateAdapters([AdapterSpec<Model>()], converters: [_LocalConverter()])
class Model {
  const Model(this.uri);
  final Uri uri;
}
''',
        },
        imports: [
          "import 'package:hive_ce_generator_test/hive/hive_adapters.dart';",
        ],
        body: '''
    final box = await Hive.openBox<Model>('models');
    final uri = Uri.parse('https://local.test');
    await box.put('m', Model(uri));
    await box.close();

    final reopened = await Hive.openBox<Model>('models');
    if (reopened.get('m')!.uri != uri) throw StateError('uri mismatch');
    await reopened.close();
''',
      );

      await expectGeneration(
        input: {
          ...pubspec(),
          'lib/other.dart': '''
import 'package:hive_ce/hive_ce.dart';

class PublicConverter extends HiveConverter<Uri, String> {
  const PublicConverter._();

  @override
  Uri fromHive(String value) => Uri.parse(value);

  @override
  String toHive(Uri value) => value.toString();
}

const exposedList = [PublicConverter._()];
''',
          'lib/hive/hive_adapters.dart': '''
import 'package:hive_ce/hive_ce.dart';
import '../other.dart';

part 'hive_adapters.g.dart';

@GenerateAdapters([AdapterSpec<Model>()], converters: exposedList)
class Model {
  const Model(this.uri);
  final Uri uri;
}
''',
        },
        throws: 'is private and cannot be accessed',
      );
    });

    test('@HiveType does not configure converters', () async {
      await expectGeneration(
        input: {
          ...pubspec(),
          'lib/model.dart': '''
import 'package:hive_ce/hive_ce.dart';
part 'model.g.dart';

@HiveType(typeId: 0)
class Model {
  const Model(this.uri);

  @HiveField(0)
  final Uri uri;
}
''',
        },
        output: {
          'lib/model.hive_type_adapter_generator.g.part': allOf(
            contains('fields[0] as Uri'),
            contains('..write(obj.uri)'),
          ),
        },
      );
    });
  });
}
