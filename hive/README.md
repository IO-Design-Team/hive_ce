<p align="center">
  <img src="https://raw.githubusercontent.com/IO-Design-Team/hive_ce/master/.github/logo_transparent.svg?sanitize=true" width="350px">
</p>
<h2 align="center">Fast, Enjoyable & Secure NoSQL Database</h2>

[![Dart CI](https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml/badge.svg)](https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml) [![codecov](https://codecov.io/gh/IO-Design-Team/hive_ce/graph/badge.svg?token=ODO2JA4286)](https://codecov.io/gh/IO-Design-Team/hive_ce) [![Pub Version](https://img.shields.io/pub/v/hive_ce?label=pub.dev&labelColor=333940&logo=dart)](https://pub.dev/packages/hive_ce) [![GitHub](https://img.shields.io/github/license/IO-Design-Team/hive_ce?color=%23007A88&labelColor=333940&logo=apache)](https://github.com/IO-Design-Team/hive_ce/blob/master/LICENSE)

[![PubStats Popularity](https://pubstats.dev/badges/packages/hive_ce/popularity.svg)](https://pubstats.dev/packages/hive_ce) [![PubStats Rank](https://pubstats.dev/badges/packages/hive_ce/rank.svg)](https://pubstats.dev/packages/hive_ce) [![PubStats Dependents](https://pubstats.dev/badges/packages/hive_ce/dependents.svg)](https://pubstats.dev/packages/hive_ce)

Hive is a lightweight and blazing fast key-value database written in pure Dart. Inspired by [Bitcask](https://en.wikipedia.org/wiki/Bitcask).

## Tutorial

For a quick tutorial, see [this wonderful post](https://onlyflutter.com/how-to-add-a-local-database-using-hive-in-flutter) by [Tijn van den Eijnde](https://x.com/TijnvdEijnde)

## Features

- 🚀 Cross platform: mobile, desktop, browser
- ⚡ Great performance (see [benchmark](#benchmark))
- ❤️ Simple, powerful, & intuitive API
- 🔒 Strong encryption built in
- 🎈 **NO** native dependencies
- 🔋 Batteries included

## New features in Hive CE

Hive CE is a spiritual continuation of Hive v2 with the following new features:

- Flutter web WASM support
- Support for Sets
- A built in Duration adapter
- A `HiveRegistrar` extension that lets you register all your generated adapters in one call
- Support for constructor parameter defaults
- Freezed support
- Support for generating adapters with classes that use named imports
- Automatic type adapter generation using the `GenerateAdapters` annotation
  - No more manually adding annotations to every type and field
  - Generate adapters for classes outside the current package
- Extends the maximum type ID from `223` to `65439`

## Hive CE (v2) vs Hive v4 (Isar)

You may be considering attempting to make the dev version of Hive v4 work in your project. I _strongly_ advise against this. Not only is Hive v4 not stable, but it is also much slower and less efficient than Hive CE.

This is a comparison of the time to complete a given number of write operations and the resulting database file size:

| Operations | Hive CE |           | Hive v4 |           |
| ---------- | ------- | --------- | ------- | --------- |
| 10         | 0.00 s  | 0.00 MB   | 0.01 s  | 1.00 MB   |
| 100        | 0.01 s  | 0.01 MB   | 0.01 s  | 1.00 MB   |
| 1,000      | 0.05 s  | 0.11 MB   | 0.07 s  | 1.00 MB   |
| 10,000     | 0.21 s  | 1.10 MB   | 0.69 s  | 5.00 MB   |
| 100,000    | 1.53 s  | 10.97 MB  | 7.01 s  | 30.00 MB  |
| 1,000,000  | 19.97 s | 109.67 MB | 89.81 s | 290.00 MB |

Database size in Hive v4 is directly affected by the length of field names in model classes which is not ideal. Also Hive v4 is much slower than Hive CE for large numbers of operations.

The benchmark was performed on an M3 Max MacBook Pro. You can [see the benchmark code here](../benchmarks/storage/bin/bench.dart).

## Migrating from Hive v2

The `hive_ce` package is a drop in replacement for Hive v2. Make the following replacements in your project:

pubspec.yaml

```yaml
# old dependencies
dependencies:
  hive: ^2.0.0
  hive_flutter: ^1.0.0

dev_dependencies:
  hive_generator: ^1.0.0

# new dependencies
dependencies:
  hive_ce: latest
  hive_ce_flutter: latest

dev_dependencies:
  hive_ce_generator: latest
```

Dart files

```dart
// old imports
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// new imports
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
```

## Workaround for transitive Hive dependencies

If you are using a package that depends on Hive v2, you can use the following workaround to force it to use Hive CE:

```yaml
dependencies:
  # Depend on hive_ce to prevent resolving breaking versions
  hive_ce: latest

dependency_overrides:
  hive:
    git:
      url: https://github.com/IO-Design-Team/hive_ce
      ref: 18f92b53295e9eb77ebd4830d905a72cd404a126
      path: overrides/hive
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

## BoxCollections

`BoxCollections` are a set of boxes which can be similarly used as normal boxes, except of that
they dramatically improve speed on web. They support opening and closing all boxes of a collection
at once and more efficiently store data in indexed DB on web.

Aside, they also expose Transactions which can be used to speed up tremendous numbers of database
transactions on web.

On `dart:io` platforms, there is no performance gain by BoxCollections or Transactions. Only
BoxCollections might be useful for some box hierarchy and development experience.

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

## Store objects

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

Some migrations may require manual modifications to the Hive schema file. One example is class/field renaming. Without manual intervention, the generator will see both an added and removed class/field. To resolve this, manually rename the class/field in the schema.

### Migrating to `GenerateAdapters`

If you already have model classes with `HiveType` and `HiveField` annotations, you can take the following steps to migrate to the new `GenerateAdapters` annotation:

1. Convert all default values to constructor parameter defaults
2. Add the following to your `build.yaml` file:

```yaml
targets:
  $default:
    builders:
      hive_ce_generator|hive_schema_migrator:
        enabled: true
```

3. Run the `build_runner`. This will generate `lib/hive/hive_adapters.dart` and `lib/hive/hive_adapters.g.yaml`.
4. Revert the `build.yaml` changes
5. Remove all explicit `HiveType` and `HiveField` annotations from your model classes
6. Run the `build_runner` again

### Explicitly defining HiveTypes

The old method of defining HiveTypes is still supported, but should be unnecessary now that Hive CE supports constructor parameter defaults. If you have a use-case that `GenerateAdapters` does not support, please [create an issue on GitHub](https://github.com/IO-Design-Team/hive_ce/issues/new).

Unfortunately it is not possible for `GenerateAdapters` to handle private fields. You can use `@protected` instead if necessary.

## Add fields to objects

When adding a new non-nullable field to an existing object, you need to specify a default value to ensure compatibility with existing data.

For example, consider an existing database with a `Person` object:

<!-- embedme readme/add_fields/person_1.dart -->

```dart
import 'package:hive_ce/hive.dart';

class Person extends HiveObject {
  Person({required this.name, required this.age});

  String name;
  int age;
}

```

If you want to add a `balance` field, you must specify a default value or else reading existing data will result in null errors:

<!-- embedme readme/add_fields/person_2.dart -->

```dart
import 'package:hive_ce/hive.dart';

class Person extends HiveObject {
  Person({required this.name, required this.age, this.balance = 0});

  String name;
  int age;
  double balance;
}

```

After modifying the model, remember to run `build_runner` to regenerate the TypeAdapters

## Hive ❤️ Flutter

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

## Benchmark

|                                         1000 read iterations                                         |                                      1000 write iterations                                       |
| :--------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------------: |
|   ![](https://raw.githubusercontent.com/IO-Design-Team/hive_ce/master/.github/benchmark_read.png)    | ![](https://raw.githubusercontent.com/IO-Design-Team/hive_ce/master/.github/benchmark_write.png) |
| SharedPreferences is on par with Hive when it comes to read performance. SQLite performs much worse. |   Hive greatly outperforms SQLite and SharedPreferences when it comes to writing or deleting.    |

The benchmark was performed on a Oneplus 6T with Android Q. You can [run the benchmark yourself](https://github.com/hivedb/hive_benchmark).

\*Take this benchmark with a grain of salt. It is very hard to compare databases objectively since they were made for different purposes.

### Licence

```
Copyright 2019 Simon Leier

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
