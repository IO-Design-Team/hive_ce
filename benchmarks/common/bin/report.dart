import 'package:storage_benchmark/report.dart';

void main(List<String> files) {
  writeReport([for (final file in files) ...readResultFile(file)]);
}
