import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const _assetName = 'src/zlib/zlib.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final targetOS = input.config.code.targetOS;
    if (targetOS == OS.windows) {
      await CBuilder.library(
        name: 'hive_ce_zlib',
        assetName: _assetName,
        sources: ['src/zlib/crc32.c'],
        defines: {'ZLIB_DLL': null},
      ).run(input: input, output: output);
      return;
    }

    final library = switch (targetOS) {
      OS.iOS || OS.macOS => '/usr/lib/libz.1.dylib',
      OS.android => 'libz.so',
      OS.linux => 'libz.so.1',
      _ => null,
    };
    if (library == null) return;

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingSystem(Uri.file(library)),
      ),
    );
  });
}
