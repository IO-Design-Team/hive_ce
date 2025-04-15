import 'package:meta/meta.dart';

/// An error related to Hive.
@immutable
class HiveError extends Error {
  /// A description of the error.
  final String message;

  /// Create a new Hive error (internal)
  HiveError(this.message);

  @override
  String toString() {
    return 'HiveError: $message';
  }
}
