import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/model/box_data.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class BoxView extends StatelessWidget {
  final BoxData data;

  const BoxView({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    if (data.frames.isEmpty) {
      return const Center(child: Text('Box is empty'));
    }

    final firstValue = data.frames.values.first.value;
    final int columnCount;
    if (firstValue is RawObject) {
      columnCount = 1 + firstValue.fields.length;
    } else {
      columnCount = 2;
    }

    final objectData =
        data.frames.values.map((e) => KeyedObject(e.key, e.value)).toList();

    return TableView.builder(
      rowCount: objectData.length + 1,
      columnCount: columnCount,
      pinnedRowCount: 1,
      pinnedColumnCount: 1,
      rowBuilder: (index) => const TableSpan(extent: FixedSpanExtent(20)),
      columnBuilder: (index) => const TableSpan(extent: FixedSpanExtent(100)),
      cellBuilder: (context, vicinity) {
        final TableVicinity(:row, :column) = vicinity;
        final rowIndex = row - 1;
        final columnIndex = column - 1;

        if (row == 0 && column == 0) {
          return const TableViewCell(child: Text('Key'));
        }

        if (row == 0) {
          return TableViewCell(child: Text(columnIndex.toString()));
        }

        final object = objectData.reversed.elementAt(rowIndex);

        if (column == 0) {
          return TableViewCell(child: Text(object.key.toString()));
        }

        final objectValue = object.value;
        final Object? fieldValue;
        if (objectValue is RawObject) {
          fieldValue = objectValue.fields.elementAt(columnIndex).value;
        } else {
          fieldValue = objectValue;
        }

        return TableViewCell(child: Text(fieldValue.toString()));
      },
    );
  }
}

class KeyedObject {
  final Object key;
  final Object? value;

  const KeyedObject(this.key, this.value);
}
