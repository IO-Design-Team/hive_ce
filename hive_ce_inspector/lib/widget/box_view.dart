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
  final List<List<KeyedObject>> _stack = [];

  List<List<KeyedObject>> get stack => [
    widget.data.frames.values.map((e) => KeyedObject(e.key, e.value)).toList(),
    ..._stack,
  ];

  @override
  void didUpdateWidget(BoxView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.name == widget.data.name) return;
    setState(_stack.clear);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.frames.isEmpty) {
      return const Center(child: Text('Box is empty'));
    }

    return DataTableView(
      data: stack.last,
      onStack: (data) => setState(() => _stack.add(data)),
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
  final ValueSetter<List<KeyedObject>> onStack;

  const DataTableView({super.key, required this.data, required this.onStack});

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

        if (fieldValue is Iterable) {
          final list = fieldValue.toList();
          if (list.isEmpty) {
            return const TableViewCell(child: Text('[Empty]'));
          }
          return TableViewCell(
            child: InkWell(
              child: const Text('[Iterable]'),
              onTap:
                  () => onStack([
                    for (var i = 0; i < list.length; i++)
                      KeyedObject(i, list[i]),
                  ]),
            ),
          );
        } else {
          return TableViewCell(child: Text(fieldValue.toString()));
        }
      },
    );
  }
}
