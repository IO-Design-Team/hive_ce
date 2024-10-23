<p align="center">
  <img src="https://raw.githubusercontent.com/IO-Design-Team/hive_ce/master/.github/logo_transparent.svg?sanitize=true" width="350px">
</p>
<h2 align="center">Fast, Enjoyable & Secure NoSQL Database</h2>

[![Dart CI](https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml/badge.svg)](https://github.com/IO-Design-Team/hive_ce/actions/workflows/test.yml) [![codecov](https://codecov.io/gh/IO-Design-Team/hive_ce/graph/badge.svg?token=ODO2JA4286)](https://codecov.io/gh/IO-Design-Team/hive_ce) [![Pub Version](https://img.shields.io/pub/v/hive_ce?label=pub.dev&labelColor=333940&logo=dart)](https://pub.dev/packages/hive_ce) [![GitHub](https://img.shields.io/github/license/IO-Design-Team/hive_ce?color=%23007A88&labelColor=333940&logo=apache)](https://github.com/IO-Design-Team/hive_ce/blob/master/LICENSE)

Hive is a lightweight and blazing fast key-value database written in pure Dart. Inspired by [Bitcask](https://en.wikipedia.org/wiki/Bitcask).

### [Documentation & Samples](https://docs.hivedb.dev/) 📖

If you need queries, multi-isolate support or links between objects check out [Isar Database](https://github.com/isar/isar).

## Migrating from Hive

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

## Features

- 🚀 Cross platform: mobile, desktop, browser
- ⚡ Great performance (see [benchmark](#benchmark))
- ❤️ Simple, powerful, & intuitive API
- 🔒 Strong encryption built in
- 🎈 **NO** native dependencies
- 🔋 Batteries included

## Getting Started

Check out the [Quick Start](https://docs.hivedb.dev) documentation to get started.

## Usage

You can use Hive just like a map. It is not necessary to await `Futures`.

```dart
var box = Hive.box('myBox');

box.put('name', 'David');

var name = box.get('name');

print('Name: $name');
```

## BoxCollections

`BoxCollections` are a set of boxes which can be similarly used as normal boxes, except of that
they dramatically improve speed on web. They support opening and closing all boxes of a collection
at once and more efficiently store data in indexed DB on web.

Aside, they also expose Transactions which can be used to speed up tremendous numbers of database
transactions on web.

On `dart:io` platforms, there is no performance gain by BoxCollections or Transactions. Only
BoxCollections might be useful for some box hierarchy and development experience.

```dart
// Create a box collection
  final collection = await BoxCollection.open(
    'MyFirstFluffyBox', // Name of your database
    {'cats', 'dogs'}, // Names of your boxes
    path: './', // Path where to store your boxes (Only used in Flutter / Dart IO)
    key: HiveCipher(), // Key to encrypt your boxes (Only used in Flutter / Dart IO)
  );

  // Open your boxes. Optional: Give it a type.
  final catsBox = collection.openBox<Map>('cats');

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
```

## Store objects

Hive not only supports primitives, lists and maps but also any Dart object you like. You need to generate a type adapter before you can store objects.

```dart
@HiveType(typeId: 0)
class Person extends HiveObject {

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;
}
```

Add the following to your pubspec.yaml

```yaml
dev_dependencies:
  build_runner: latest
  hive_ce_generator: latest
```

And run the following command to generate the type adapter

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate all of your `TypeAdapter`s as well as a Hive extension to register them all in one go

```dart
import 'package:your_package/hive_registrar.g.dart';

void main() {
  final path = Directory.current.path;
  Hive
    ..init(path)
    ..registerAdapters();
}
```

Extending `HiveObject` is optional but it provides handy methods like `save()` and `delete()`.

```dart
var box = await Hive.openBox('myBox');

var person = Person()
  ..name = 'Dave'
  ..age = 22;
box.add(person);

print(box.getAt(0)); // Dave - 22

person.age = 30;
person.save();

print(box.getAt(0)) // Dave - 30
```

## Add fields to objects

When adding a new non-nullable field to an existing object, you need to specify a default value to ensure compatibility with existing data.

For example, consider an existing database with a `Person` object:

```dart
@HiveType(typeId: 0)
class Person extends HiveObject {
  Person({required this.name, required this.age});

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;
}
```

If you want to add a `balance` field:

```dart
@HiveType(typeId: 0)
class Person extends HiveObject {
  Person({required this.name, required this.age, required this.balance});

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @HiveField(2)
  int balance;
}
```

Without proper handling, this change will cause null errors in the existing application when accessing the new field.

To resolve this issue, you can set a default value in the constructor (this requires hive_ce_generator 1.5.0+)

```dart
@HiveType(typeId: 0)
class Person extends HiveObject {
  Person({required this.name, required this.age, this.balance = 0});

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @HiveField(2)
  int balance;
}
```

Or specify it in the `HiveField` annotation:

```dart
@HiveField(2, defaultValue: 0)
int balance;
```

Alternatively, you can write custom migration code to handle the transition.

After modifying the schema, remember to run the build runner to generate the necessary code:

```console
flutter pub run build_runner build --delete-conflicting-outputs
```

This will update your Hive adapters to reflect the changes in your object structure.

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
