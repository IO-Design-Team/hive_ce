import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/model/box_data.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class BoxView extends StatefulWidget {
  final BoxData data;

  const BoxView({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    if (data.frames.isEmpty) {
      return const Center(child: Text('Box is empty'));
    }

    final frames = data.frames.values.toList();
    final frameFields = fieldsForFrames(frames);
    final columnCount = 1 + (frameFields.values.firstOrNull?.length ?? 0);

    return TableView.builder(
      rowCount: frames.length + 1,
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
          final field = frameFields.values.first[columnIndex];
          return TableViewCell(child: Text(field.index.toString()));
        }

        final frame = frames.reversed.elementAt(rowIndex);

        if (column == 0) {
          return TableViewCell(child: Text(frame.key.toString()));
        }

        final field = frameFields[frame.key]![columnIndex];
        return TableViewCell(child: Text(field.value.toString()));
      },
    );
  }

  Map<Object, List<IndexedObject>> fieldsForFrames(
    List<InspectorFrame> frames,
  ) {
    final fields = <Object, List<IndexedObject>>{};

    for (final frame in frames) {
      final value = frame.value;
      if (value is RawObject) {
        fields[frame.key] = fieldsForObject(value);
      } else {
        fields[frame.key] = [IndexedObject(0, value)];
      }
    }

    return fields;
  }

  List<IndexedObject> fieldsForObject(RawObject object) {
    final fields = <IndexedObject>[];

    for (final field in object.fields) {
      final index = field.index;
      final value = field.value;
      if (value is RawObject) {
        print('INDEX: $index, VALUE: ${value.fields.map((e) => e.value)}');
        fields.addAll(fieldsForObject(value));
      } else {
        print('INDEX: $index, VALUE: $value');
        fields.add(IndexedObject(index, value));
      }
    }

    return fields;
  }
}

class IndexedObject {
  final int index;
  final Object? value;

  const IndexedObject(this.index, this.value);
}
