<p align="center">
  <img src="https://raw.githubusercontent.com/IO-Design-Team/hive_ce/master/.github/logo_transparent.svg?sanitize=true" width="350px">
</p>
<h2 align="center">Fast, Enjoyable & Secure NoSQL Database</h2>

<p align="center">
  <a href="https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml"><img src="https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml/badge.svg" alt="Dart CI"></a>
  <a href="https://codecov.io/gh/IO-Design-Team/hive_ce"><img src="https://codecov.io/gh/IO-Design-Team/hive_ce/graph/badge.svg?token=ODO2JA4286" alt="codecov"></a>
  <a href="https://pub.dev/packages/hive_ce"><img src="https://img.shields.io/pub/v/hive_ce?label=pub.dev&labelColor=333940&logo=dart" alt="Pub Version"></a>
  <a href="https://github.com/IO-Design-Team/hive_ce/blob/master/LICENSE"><img src="https://img.shields.io/badge/License-BSD_3--Clause-007A88.svg?logo=bsd" alt="License"></a>
</p>

<p align="center">
  <a href="https://pubstats.dev/packages/hive_ce"><img src="https://pubstats.dev/badges/packages/hive_ce/popularity.svg" alt="PubStats Popularity"></a>
  <a href="https://pubstats.dev/packages/hive_ce"><img src="https://pubstats.dev/badges/packages/hive_ce/rank.svg" alt="PubStats Rank"></a>
  <a href="https://pubstats.dev/packages/hive_ce"><img src="https://pubstats.dev/badges/packages/hive_ce/dependents.svg" alt="PubStats Dependents"></a>
</p>

Hive is a lightweight and blazing fast key-value database written in pure Dart. Inspired by [Bitcask](https://en.wikipedia.org/wiki/Bitcask).

### [Documentation & Samples](https://docs.hive.isar.community) 📖

## Features

- 🚀 Cross platform: mobile, desktop, browser
- ⚡ Great performance (see [benchmark](#benchmark))
- ❤️ Simple, powerful, & intuitive API
- 🔒 Strong encryption built in
- 🎈 **NO** native dependencies
- 🔋 Batteries included

## New features in Hive CE

Hive CE is a spiritual continuation of Hive v2 with the following new features:

- Hive CE Inspector DevTools extension
  - Quickly and easily inspect the content of Hive boxes
- Isolate support through `IsolatedHive`
- Flutter web WASM support
- Automatic type adapter generation using the `GenerateAdapters` annotation
  - No more manually adding annotations to every type and field
  - Generate adapters for classes outside the current package
- A `HiveRegistrar` extension that lets you register all your generated adapters in one call
- Extends the maximum type ID from `223` to `65439`
- Support for constructor parameter defaults
- Support for Sets
- A built in Duration adapter
- Freezed support
- Support for generating adapters with classes that use named imports

## Benchmark

This is a comparison of the time to complete a given number of write operations and the resulting database file size:

| Operations | Hive CE Time | IsolatedHive Time | Hive CE Size | Hive v4 Time | Hive v4 Size |
| ---------- | ------------ | ----------------- | ------------ | ------------ | ------------ |
| 10         | 0.00 s       | 0.00 s            | 0.00 MB      | 0.00 s       | 1.00 MB      |
| 100        | 0.00 s       | 0.01 s            | 0.01 MB      | 0.01 s       | 1.00 MB      |
| 1000       | 0.02 s       | 0.03 s            | 0.11 MB      | 0.06 s       | 1.00 MB      |
| 10000      | 0.13 s       | 0.25 s            | 1.10 MB      | 0.64 s       | 5.00 MB      |
| 100000     | 1.40 s       | 2.64 s            | 10.97 MB     | 7.26 s       | 30.00 MB     |
| 1000000    | 19.94 s      | 41.50 s           | 109.67 MB    | 84.87 s      | 290.00 MB    |

Database size in Hive v4 is directly affected by the length of field names in model classes which is not ideal. Also Hive v4 is much slower than Hive CE for large numbers of operations.

IsolatedHive is slower than Hive, but it is much faster than Hive v4 and you still get the benefit of multiple isolate support.

The benchmark was performed on an M3 Max MacBook Pro. You can [see the benchmark code here](https://github.com/IO-Design-Team/hive_ce/blob/main/benchmarks/storage/bin/bench.dart).

## Migration guides

- [Hive v2 to Hive CE](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#v2-to-ce)
- [Transitive Hive dependencies](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#transitive-hive-dependencies)
- [Migrating to `GenerateAdapters`](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#generate-adapters)
- [Add fields to objects](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/MIGRATION.md#add-fields)

## Getting Started

Hive CE requires Dart 3. Ensure that you have the following in your `pubspec.yaml` file:

```yaml
environment:
  sdk: ^3.0.0
```

## Usage

You can use Hive just like a map. It is not necessary to await `Futures`.

<!-- embedme readme/usage.dart -->

```dart
import 'package:hive_ce/hive.dart';

void example() {
  final box = Hive.box('myBox');
  box.put('name', 'David');
  final name = box.get('name');
  print('Name: $name');
}

```

## Guides

<details>
<summary>Hive CE Inspector</summary>

When your app is running in debug mode, you can use the Hive CE Inspector to inspect boxes:

1. Press `Ctrl+Shift+P`
2. Select `Dart: Open DevTools`
3. Select `Open DevTools in Web Browser`
4. Navigate to the `hive_ce` tab

There are some requirements for using the inspector:

- All types you wish to view in the inspector must have type adapters generated by a `GenerateAdapters` annotation
  - For any types not handled by `GenerateAdapters`, only raw binary data will be shown
  - This means types annotated with `HiveType` and types using custom type adapters will not be deserialized
- Hive schemas (`hive_adapters.g.yaml`) are used to deserialize data
  - All necessary Hive schemas must be in the `lib` folder of a project open in the IDE workspace
  - This should work by default for most projects. Otherwise, you may need to copy the necessary Hive schemas into an open project's `lib` folder.

</details>

<details>
<summary>IsolatedHive (isolate support)</summary>

`IsolatedHive` allows you to safely use `Hive` in a multi-isolate environment by maintaining its own separate isolate for `Hive` operations

Here are some common examples of multi-isolate scenarios:

- A Flutter desktop app with multiple windows
- Running background tasks with [flutter_workmanager](https://pub.dev/packages/workmanager), [background_fetch](https://pub.dev/packages/background_fetch), etc
- Push notification processing

`IsolatedHive` has a very similar API to `Hive`, but there are some key differences:

- The `init` call takes an `isolateNameServer` parameter
- Most methods are asynchronous due to isolate communication
- `IsolatedHive` does not support `HiveObject` or `HiveList`
- Isolate communication does add some overhead. See the benchmarks above.

NOTE: On web, `IsolatedHive` directly calls `Hive` since web does not support isolates

### Usage

<!-- embedme readme/isolated_hive.dart -->

```dart
import 'package:hive_ce/hive.dart';

import 'stub_ins.dart';

void main() async {
  await IsolatedHive.init('.', isolateNameServer: StubIns());
  final box = await IsolatedHive.openBox('box');
  await box.put('key', 'value');
  print(await box.get('key')); // reading is async
}

```

IMPORTANT: If you are using `IsolatedHive`, you MUST use it everywhere in place of the normal `Hive` interface

NOTE: It is possible to use `IsolatedHive` without an `IsolateNameServer`, BUT THIS IS UNSAFE. The `IsolateNameServer` is what allows `IsolatedHive` to locate and communicate with a single backend isolate.

Additional notes:

- With Flutter, use `IsolatedHive.initFlutter` from `hive_ce_flutter` to initialize `IsolatedHive` with Flutter's `IsolateNameServer`
- There is also an `IsolatedHive.registerAdapters` method if you use `hive_ce_generator` to generate adapters

### Example

See an example of a multi-window Flutter app using `IsolatedHive` [here](https://github.com/Rexios80/hive_ce_multiwindow)

</details>

<details>
<summary>Store objects</summary>

Hive not only supports primitives, lists, and maps but also any Dart object you like. You need to generate type adapters before you can store custom objects.

### Create model classes

<!-- embedme readme/store_objects/person.dart -->

```dart
import 'package:hive_ce/hive.dart';

class Person extends HiveObject {
  Person({required this.name, required this.age});

  String name;
  int age;
}

```

### Create a `GenerateAdapters` annotation

Usually this is placed in `lib/hive/hive_adapters.dart`

<!-- embedme readme/store_objects/hive_adapters.dart -->

```dart
import 'package:hive_ce/hive.dart';
import 'person.dart';

@GenerateAdapters([AdapterSpec<Person>()])
part 'hive_adapters.g.dart';

```

### Update `pubspec.yaml`

```yaml
dev_dependencies:
  build_runner: latest
  hive_ce_generator: latest
```

### Run `build_runner`

```bash
dart pub run build_runner build --delete-conflicting-outputs
```

This will generate the following:

- TypeAdapters for the specified AdapterSpecs
- TypeAdapters for all explicitly defined HiveTypes
- A `hive_adapters.g.dart` file containing all adapters generated from the `GenerateAdapters` annotation
- A `hive_adapters.g.yaml` file
- A `hive_registrar.g.dart` file containing an extension method to register all generated adapters

All of the generated files should be checked into version control. These files are explained in more detail below.

### Use the Hive registrar

The Hive Registrar allows you to register all generated TypeAdapters in one call

```dart
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:your_package/hive/hive_registrar.g.dart';

void main() {
  Hive
    ..init(Directory.current.path)
    ..registerAdapters();
}
```

### Using HiveObject methods

Extending `HiveObject` is optional but it provides handy methods like `save()` and `delete()`.

<!-- embedme readme/store_objects/hive_object.dart -->

```dart
import 'package:hive_ce/hive.dart';
import 'person.dart';

void example() async {
  final box = await Hive.openBox('myBox');

  final person = Person(name: 'Dave', age: 22);
  await box.add(person);

  print(box.getAt(0)); // Dave - 22

  person.age = 30;
  await person.save();

  print(box.getAt(0)); // Dave - 30
}

```

### About `hive_adapters.g.yaml`

The Hive schema is a generated yaml file that contains the information necessary to incrementally update the generated TypeAdapters as your model classes evolve.

**IMPORTANT**: There will be a lot of churn in this file during initial development. Make sure to delete `hive_adapters.g.yaml` and regenerate before the first real deployment of your application to reclaim unused field indices.

Some migrations may require manual modifications to the Hive schema file. One example is class/field renaming. Without manual intervention, the generator will see both an added and removed class/field. To resolve this, manually rename the class/field in the schema.

### Explicitly defining HiveTypes

The old method of defining HiveTypes is still supported, but should be unnecessary now that Hive CE supports constructor parameter defaults. If you have a use-case that `GenerateAdapters` does not support, please [create an issue on GitHub](https://github.com/IO-Design-Team/hive_ce/issues/new).

Unfortunately it is not possible for `GenerateAdapters` to handle private fields. You can use `@protected` instead if necessary.

</details>

<details>
<summary>BoxCollection</summary>

`BoxCollections` are a set of boxes which can be similarly used as normal boxes, except of that
they dramatically improve speed on web. They support opening and closing all boxes of a collection
at once and more efficiently store data in indexed DB on web.

Aside, they also expose Transactions which can be used to speed up tremendous numbers of database
transactions on web.

On `dart:io` platforms, there is no performance gain by BoxCollections or Transactions. Only
BoxCollections might be useful for some box hierarchy and development experience.

Custom objects must be json serializable in order to be used with BoxCollections.

<!-- embedme readme/box_collections.dart -->

```dart
import 'package:hive_ce/hive.dart';
import 'hive_cipher_impl.dart';

void example() async {
  // Create a box collection
  final collection = await BoxCollection.open(
    // Name of your database
    'MyFirstFluffyBox',
    // Names of your boxes
    {'cats', 'dogs'},
    // Path where to store your boxes (Only used in Flutter / Dart IO)
    path: './',
    // Key to encrypt your boxes (Only used in Flutter / Dart IO)
    key: HiveCipherImpl(),
  );

  // Open your boxes. Optional: Give it a type.
  final catsBox = await collection.openBox<Map>('cats');

  // Put something in
  await catsBox.put('fluffy', {'name': 'Fluffy', 'age': 4});
  await catsBox.put('loki', {'name': 'Loki', 'age': 2});

  // Get values of type (immutable) Map?
  final loki = await catsBox.get('loki');
  print('Loki is ${loki?['age']} years old.');

  // Returns a List of values
  final cats = await catsBox.getAll(['loki', 'fluffy']);
  print(cats);

  // Returns a List<String> of all keys
  final allCatKeys = await catsBox.getAllKeys();
  print(allCatKeys);

  // Returns a Map<String, Map> with all keys and entries
  final catMap = await catsBox.getAllValues();
  print(catMap);

  // delete one or more entries
  await catsBox.delete('loki');
  await catsBox.deleteAll(['loki', 'fluffy']);

  // ...or clear the whole box at once
  await catsBox.clear();

  // Speed up write actions with transactions
  await collection.transaction(
    () async {
      await catsBox.put('fluffy', {'name': 'Fluffy', 'age': 4});
      await catsBox.put('loki', {'name': 'Loki', 'age': 2});
      // ...
    },
    boxNames: ['cats'], // By default all boxes become blocked.
    readOnly: false,
  );
}

```

</details>

<details>
<summary>Hive ❤️ Flutter</summary>

Hive was written with Flutter in mind. It is a perfect fit if you need a lightweight datastore for your app. After adding the required dependencies and initializing Hive, you can use Hive in your project:

```dart
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, widget) {
        return Switch(
          value: box.get('darkMode'),
          onChanged: (val) {
            box.put('darkMode', val);
          }
        );
      },
    );
  }
}
```

Boxes are cached and therefore fast enough to be used directly in the `build()` method of Flutter widgets.

</details>
