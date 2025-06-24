import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/model/box_data.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class BoxView extends StatefulWidget {
  final BoxData data;

  const BoxView({super.key, required this.data});

  @override
  State<StatefulWidget> createState() => _BoxViewState();
}

class _BoxViewState extends State<BoxView> {
  /// Stack of table views
  final List<List<KeyedObject>> stack = [];

  @override
  Widget build(BuildContext context) {
    if (widget.data.frames.isEmpty) {
      return const Center(child: Text('Box is empty'));
    }

    return DataTableView(
      data:
          widget.data.frames.values
              .map((e) => KeyedObject(e.key, e.value))
              .toList(),
    );
  }
}

class KeyedObject {
  final Object key;
  final Object? value;

  const KeyedObject(this.key, this.value);
}

class DataTableView extends StatelessWidget {
  final List<KeyedObject> data;

  const DataTableView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final firstValue = data.first.value;
    final int columnCount;
    if (firstValue is RawObject) {
      columnCount = 1 + firstValue.fields.length;
    } else {
      columnCount = 2;
    }

    return TableView.builder(
      rowCount: data.length + 1,
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

        final object = data.reversed.elementAt(rowIndex);

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
