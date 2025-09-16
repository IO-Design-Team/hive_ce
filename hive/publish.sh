cd ../hive_ce_inspector
dart pub get
flutter build web --wasm
rm -rf ../hive/extension/devtools/build
cp -r build/web ../hive/extension/devtools/build
dart run devtools_extensions validate --package=../hive

cd ../hive
dart pub publish