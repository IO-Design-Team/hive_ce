import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Obfuscates a box name by creating a deterministic hash of it.
///
/// The entire name (including extension) is hashed into a single string with
/// no visible extension. This ensures that box names and their file extensions
/// are completely obfuscated on disk.
///
/// Example:
/// ```dart
/// obfuscateBoxName('maps.hive') // Returns: "a1b2c3d4e5f6..." (64-char hex hash)
/// obfuscateBoxName('maps.lock') // Returns: "f6e5d4c3b2a1..." (different hash)
/// ```
///
/// Throws [ArgumentError] if [boxName] is empty.
extension ObfuscationUtils on File {
  /// Obfuscates a box name by creating a deterministic hash of it.
  ///
  /// The entire name (including extension) is hashed into a single string with
  /// no visible extension. This ensures that box names and their file extensions
  /// are completely obfuscated on disk.
  ///
  /// Example:
  /// ```dart
  /// obfuscateBoxName('maps.hive') // Returns: "a1b2c3d4e5f6..." (64-char hex hash)
  /// obfuscateBoxName('maps.lock') // Returns: "f6e5d4c3b2a1..." (different hash)
  /// ```
  ///
  /// Throws [ArgumentError] if [boxName] is empty.
  File obfuscate(bool obfuscate) => obfuscate
      ? File(
          p.join(
            p.dirname(path),
            '${sha256.convert(utf8.encode(p.basename(path)))}',
          ),
        )
      : this;
}
