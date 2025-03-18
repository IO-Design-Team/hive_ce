import 'dart:io';
import 'dart:math';

import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

Matcher isAHiveError([List<String> containing = const []]) {
  return allOf(
    isA<HiveError>(),
    predicate(
      (e) {
        final message = e.toString().toLowerCase();
        return containing.every((c) => message.contains(c.toLowerCase()));
      },
    ),
  );
}

Matcher throwsHiveError([List<String> containing = const []]) {
  return throwsA(isAHiveError(containing));
}

Matcher throwsIsolatedHiveError([List<String> containing = const []]) {
  return throwsA(
    anyOf([
      isAHiveError(containing),
      isA<IsolateException>().having(
        (e) => e.details,
        'details',
        contains(allOf(containing.map(contains))),
      ),
    ]),
  );
}

final random = Random();
String tempPath =
    path.join(Directory.current.path, '.dart_tool', 'test', 'tmp');
String assetsPath = path.join(Directory.current.path, 'test', 'assets');

Future<File> getTempFile([List<int>? bytes]) async {
  final name = random.nextInt(pow(2, 32) as int);
  final file = File(path.join(tempPath, '$name.tmp'));
  await file.create(recursive: true);

  if (bytes != null) {
    await file.writeAsBytes(bytes);
  }

  return file;
}

Future<RandomAccessFile> getTempRaf(
  List<int> bytes, {
  FileMode mode = FileMode.read,
}) async {
  final file = await getTempFile(bytes);
  return await file.open(mode: mode);
}

Future<Directory> getTempDir() async {
  final name = random.nextInt(pow(2, 32) as int);
  final dir = Directory(path.join(tempPath, '${name}_tmp'));
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
  await dir.create(recursive: true);
  return dir;
}

File getAssetFile(String part1, [String? part2, String? part3, String? part4]) {
  return File(path.join(assetsPath, part1, part2, part3, part4));
}

Future<File> getTempAssetFile(
  String part1, [
  String? part2,
  String? part3,
  String? part4,
]) async {
  final assetFile = getAssetFile(part1, part2, part3, part4);
  final tempFile = await getTempFile();

  return await assetFile.copy(tempFile.path);
}

Future<Directory> getAssetDir(
  String part1, [
  String? part2,
  String? part3,
  String? part4,
]) async {
  final assetDir = Directory(path.join(assetsPath, part1, part2, part3, part4));
  final tempDir = await getTempDir();

  await for (final file in assetDir.list(recursive: true)) {
    if (file is File) {
      final relative = path.relative(file.path, from: assetDir.path);
      final tempFile = File(path.join(tempDir.path, relative));
      await tempFile.create(recursive: true);
      await file.copy(tempFile.path);
    }
  }

  return tempDir;
}

Future<void> expectDirsEqual(Directory dir1, Directory dir2) {
  return _expectDirsEqual(dir1, dir2, false);
}

Future<void> _expectDirsEqual(
  Directory dir1,
  Directory dir2,
  bool round2,
) async {
  await for (final entity in dir1.list(recursive: true)) {
    if (entity is File) {
      final fileName = path.basename(entity.path);
      final otherFile = File(path.join(dir2.path, fileName));

      final entityBytes = await entity.readAsBytes();
      final otherBytes = await otherFile.readAsBytes();
      expect(entityBytes, otherBytes);
    } else if (entity is Directory) {
      final dir2Entity =
          Directory(path.join(dir2.path, path.basename(entity.path)));
      await expectDirsEqual(entity, dir2Entity);
    }
  }

  if (!round2) {
    await _expectDirsEqual(dir2, dir1, true);
  }
}

Future<void> expectDirEqualsAssetDir(
  Directory dir1,
  String part1, [
  String? part2,
  String? part3,
  String? part4,
]) {
  final assetDir = Directory(path.join(assetsPath, part1, part2, part3, part4));
  return expectDirsEqual(dir1, assetDir);
}

void returnFutureVoid(When<Future<void>> v) =>
    v.thenAnswer((i) => Future.value(null));

String generateBoxName() {
  final id = Random.secure().nextInt(99999999);
  return 'box$id';
}
