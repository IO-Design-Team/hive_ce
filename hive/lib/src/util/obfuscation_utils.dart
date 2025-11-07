import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Obfuscates a box name by creating a deterministic hash of it.
///
/// The entire name (including extension) is hashed into a single string with
/// no visible extension. This ensures that box names and their file extensions
/// are completely obfuscated on disk.
///
/// Example:
/// ```dart
/// obfuscateBoxName('maps.hive') // Returns: "1243hhvfh34hAgg" (no .hive visible)
/// obfuscateBoxName('maps.lock') // Returns: "xYz9AbC123" (different hash, no .lock visible)
/// ```
///
/// Throws [ArgumentError] if [boxName] is empty.
String obfuscateBoxName(String boxName) {
  if (boxName.isEmpty) {
    throw ArgumentError.value(
      boxName,
      'boxName',
      'Box name cannot be empty',
    );
  }

  final bytes = utf8.encode(boxName);
  final digest = sha256.convert(bytes);
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
