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
  final typeIds = <int>[];
  int? selectedTypeId;

  @override
  void initState() {
    super.initState();

    final typeIds =
        widget.data.frames.values
            .map((e) => e.value)
            .whereType<RawType>()
            .map((e) => e.typeId)
            .toSet();

    this.typeIds
      ..addAll(typeIds)
      ..sort();

    selectedTypeId = typeIds.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final List<InspectorFrame> filteredFrames;
    if (selectedTypeId == null) {
      filteredFrames = widget.data.frames.values.toList();
    } else {
      filteredFrames =
          widget.data.frames.values.where((e) {
            final value = e.value;
            return value is RawType && value.typeId == selectedTypeId;
          }).toList();
    }

    if (filteredFrames.isEmpty) {
      return const Center(child: Text('Box is empty'));
    }

    final columnCount = 2;

    return Column(
      children: [
        if (typeIds.length > 1)
          Row(
            children: [
              const Text('Type ID'),
              const Spacer(),
              DropdownButton(
                items: [
                  for (final typeId in typeIds)
                    DropdownMenuItem(
                      value: typeId,
                      child: Text(typeId.toString()),
                    ),
                ],
                onChanged: (value) => setState(() => selectedTypeId = value),
              ),
            ],
          ),
        Expanded(
          child: TableView(
            delegate: TableCellBuilderDelegate(
              rowCount: filteredFrames.length + 1,
              columnCount: columnCount,
              pinnedRowCount: 1,
              pinnedColumnCount: 1,
              rowBuilder:
                  (index) => const TableSpan(extent: FixedSpanExtent(20)),
              columnBuilder:
                  (index) => const TableSpan(extent: FixedSpanExtent(100)),
              cellBuilder: (context, vicinity) {
                final TableVicinity(:row, :column) = vicinity;
                final rowIndex = row - 1;
                final columnIndex = column - 1;

                if (row == 0 && column == 0) {
                  return const TableViewCell(child: Text('Key'));
                }

                if (row == 0) {
                  if (columnCount == 2) {
                    return const TableViewCell(child: Text('Value'));
                  } else {
                    return TableViewCell(child: Text('Field $columnIndex'));
                  }
                }

                final frame = filteredFrames.reversed.elementAt(rowIndex);
                if (column == 0) {
                  return TableViewCell(child: Text(frame.key.toString()));
                }

                return TableViewCell(child: Text(frame.value.toString()));
              },
            ),
          ),
        ),
      ],
    );
  }
}
