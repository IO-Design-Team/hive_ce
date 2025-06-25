import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/model/box_data.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:hive_ce_inspector/service/connect_client.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class BoxView extends StatefulWidget {
  final ConnectClient client;
  final HiveSchema? schema;
  final BoxData data;

  const BoxView({
    super.key,
    required this.client,
    required this.schema,
    required this.data,
  });

  @override
  State<StatefulWidget> createState() => _BoxViewState();
}

class _BoxViewState extends State<BoxView> {
  /// Stack of table views
  final List<KeyedObject<List<KeyedObject>>> _stack = [];

  List<KeyedObject<List<KeyedObject>>> get stack => [
    KeyedObject(
      widget.data.name,
      widget.data.frames.values
          .map((e) => KeyedObject(e.key, e.value, load: () => _loadFrame(e)))
          .toList()
          .reversed
          .toList(),
    ),
    ..._stack,
  ];

  void _loadFrame(InspectorFrame frame) {
    if (!frame.lazy) return;
    widget.client.loadValue(widget.data.name, frame);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.data.loaded) {
      return const Center(child: Text('Box is loading...'));
    }
    if (widget.data.frames.isEmpty) {
      return const Center(child: Text('Box is empty'));
    }

    return Column(
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(_stack.clear),
              child: Text(widget.data.name),
            ),
            ..._stack.expand(
              (e) => [
                const Text('/'),
                TextButton(
                  onPressed:
                      () => setState(
                        () => _stack.removeRange(
                          _stack.indexOf(e) + 1,
                          _stack.length,
                        ),
                      ),
                  child: Text(e.key.toString()),
                ),
              ],
            ),
          ],
        ),
        Expanded(
          child: DataTableView(
            key: ValueKey(widget.data.name),
            schema: widget.schema,
            data: stack.last.value,
            onStack:
                (key, value) =>
                    setState(() => _stack.add(KeyedObject(key, value))),
          ),
        ),
      ],
    );
  }
}

class KeyedObject<T extends Object?> {
  final Object key;
  final T value;

  // Load the value if it is lazy
  final VoidCallback? load;

  const KeyedObject(this.key, this.value, {this.load});
}

class DataTableView extends StatefulWidget {
  final HiveSchema? schema;
  final List<KeyedObject> data;
  final void Function(Object key, List<KeyedObject> value) onStack;

  const DataTableView({
    super.key,
    required this.schema,
    required this.data,
    required this.onStack,
  });

  @override
  State<StatefulWidget> createState() => _DataTableViewState();
}

class _DataTableViewState extends State<DataTableView> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstValue = widget.data.first.value;
    final int columnCount;
    final HiveSchemaType? schemaType;
    if (firstValue is RawObject) {
      columnCount = 1 + firstValue.fields.length;
      schemaType = getSchemaType(firstValue.typeId)?.value;
    } else {
      columnCount = 2;
      schemaType = null;
    }

    final query = searchController.text;
    final List<KeyedObject> filteredData;
    if (query.isEmpty) {
      filteredData = widget.data;
    } else {
      filteredData =
          widget.data
              .where(
                (e) =>
                    e.key.toString().contains(query) ||
                    e.value.toString().contains(query),
              )
              .toList();
    }

    final largeDataset = widget.data.length > 100000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 300,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                helperText: largeDataset ? 'Submit to search' : null,
              ),
              onChanged: !largeDataset ? (_) => setState(() {}) : null,
              onSubmitted: largeDataset ? (_) => setState(() {}) : null,
            ),
          ),
        ),
        filteredData.isEmpty
            ? const Expanded(child: Center(child: Text('No search results')))
            : Expanded(
              child: TableView.builder(
                rowCount: filteredData.length + 1,
                columnCount: columnCount,
                pinnedRowCount: 1,
                pinnedColumnCount: 1,
                rowBuilder:
                    (index) => const TableSpan(
                      extent: FixedSpanExtent(20),
                      padding: SpanPadding.all(4),
                    ),
                columnBuilder:
                    (index) => const TableSpan(
                      extent: FixedSpanExtent(100),
                      padding: SpanPadding.all(8),
                    ),
                cellBuilder: (context, vicinity) {
                  final TableVicinity(:row, :column) = vicinity;
                  final rowIndex = row - 1;
                  final columnIndex = column - 1;

                  if (row == 0 && column == 0) {
                    return const TableViewCell(child: Text('key'));
                  }

                  final fieldName =
                      schemaType?.fields.entries
                          .where((e) => e.value.index == columnIndex)
                          .firstOrNull
                          ?.key ??
                      columnIndex.toString();

                  if (row == 0) {
                    return TableViewCell(
                      child: Tooltip(
                        message: fieldName,
                        child: Text(fieldName),
                      ),
                    );
                  }

                  final object = filteredData[rowIndex];

                  if (column == 0) {
                    final keyString = object.key.toString();
                    final Color cellColor;
                    if (query.isNotEmpty && keyString.contains(query)) {
                      cellColor = Colors.yellow.withAlpha(50);
                    } else {
                      cellColor = Colors.transparent;
                    }
                    return TableViewCell(
                      child: Tooltip(
                        message: keyString,
                        child: ColoredBox(
                          color: cellColor,
                          child: Text(keyString),
                        ),
                      ),
                    );
                  }

                  final objectValue = object.value;
                  final Object? fieldValue;
                  if (objectValue is RawObject) {
                    fieldValue =
                        objectValue.fields.elementAt(columnIndex).value;
                  } else {
                    fieldValue = objectValue;
                  }

                  final String cellText;
                  final Widget cellContent;
                  final stackKey = '${object.key}.$fieldName';
                  if (fieldValue is Iterable) {
                    final list = fieldValue.toList();
                    if (list.isEmpty) {
                      cellText = '[Empty]';
                      cellContent = Text(cellText);
                    } else {
                      cellText = '[Iterable]';
                      cellContent = InkWell(
                        child: Text(cellText),
                        onTap:
                            () => widget.onStack(stackKey, [
                              for (var i = 0; i < list.length; i++)
                                KeyedObject(i, list[i]),
                            ]),
                      );
                    }
                  } else if (fieldValue is RawObject) {
                    final label =
                        getSchemaType(fieldValue.typeId)?.key ?? 'Object';
                    cellText = '{$label}';
                    cellContent = InkWell(
                      child: InkWell(
                        child: Text(cellText),
                        onTap:
                            () => widget.onStack(stackKey, [
                              KeyedObject(0, fieldValue),
                            ]),
                      ),
                    );
                  } else {
                    cellText = fieldValue.toString();
                    cellContent = Text(cellText);
                  }

                  final Color cellColor;
                  if (query.isNotEmpty &&
                      fieldValue.toString().contains(query)) {
                    cellColor = Colors.yellow.withAlpha(50);
                  } else {
                    cellColor = Colors.transparent;
                  }

                  return TableViewCell(
                    child: FrameLoader(
                      key: ValueKey(object.key),
                      object: object,
                      child: Tooltip(
                        message: cellText,
                        child: ColoredBox(color: cellColor, child: cellContent),
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }

  MapEntry<String, HiveSchemaType>? getSchemaType(int typeId) {
    // The RawObject type IDs are post conversion
    return widget.schema?.types.entries
        .where(
          (e) =>
              TypeRegistryImpl.calculateTypeId(
                e.value.typeId,
                internal: false,
              ) ==
              typeId,
        )
        .firstOrNull;
  }
}

/// Defers lazy frame loading for scrolling performance
class FrameLoader extends StatefulWidget {
  final KeyedObject object;
  final Widget child;

  const FrameLoader({super.key, required this.object, required this.child});

  @override
  State<StatefulWidget> createState() => _FrameLoaderState();
}

class _FrameLoaderState extends State<FrameLoader> {
  @override
  void initState() {
    super.initState();

    load();
  }

  void load() async {
    final load = widget.object.load;
    if (load == null) return;

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    load();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
