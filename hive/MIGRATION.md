<a id="v2-to-ce"></a>

# Hive v2 to Hive CE Migration

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

<a id="transitive-hive-dependencies"></a>

# Workaround for transitive Hive dependencies

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

<a id="generate-adapters"></a>

# Migrating to `GenerateAdapters`

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

<a id="add-fields"></a>

# Add fields to objects

When adding a new non-nullable field to an existing object, you need to specify a default value to ensure compatibility with existing data.

For example, consider an existing database with a `Person` object:

<!-- embedme readme/add_fields/person_1.dart -->

```dart
import 'package:meta/meta.dart';

@immutable
class Person {
  const Person({required this.name, required this.age});

  final String name;
  final int age;
}

```

If you want to add a `balance` field, you must specify a default value or else reading existing data will result in null errors:

<!-- embedme readme/add_fields/person_2.dart -->

```dart
import 'package:meta/meta.dart';

@immutable
class Person {
  const Person({required this.name, required this.age, this.balance = 0});

  final String name;
  final int age;
  final double balance;
}

```

After modifying the model, remember to run `build_runner` to regenerate the TypeAdapters
