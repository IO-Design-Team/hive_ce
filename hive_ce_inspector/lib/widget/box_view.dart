import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_inspector/model/box_data.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:hive_ce_inspector/service/connect_client.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:flutter/foundation.dart';

class BoxView extends StatefulWidget {
  final ConnectClient client;
  final BoxData data;

  const BoxView({super.key, required this.client, required this.data});

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
          .map(
            (e) => KeyedObject(
              e.key,
              e.value,
              load: e.lazy
                  ? () => widget.client.loadValue(widget.data.name, e)
                  : null,
            ),
          )
          .toList()
          .reversed
          .toList(),
    ),
    ..._stack,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);

    if (!widget.data.loaded) {
      return const Center(child: Text('Box is loading...'));
    }
    if (widget.data.frames.isEmpty) {
      return const Center(child: Text('Box is empty'));
    }

    return DevToolsAreaPane(
      header: AreaPaneHeader(
        title: Row(
          children: [
            DevToolsButton(
              outlined: false,
              label: widget.data.name,
              onPressed: () => setState(_stack.clear),
            ),
            ..._stack.expand(
              (e) => [
                const Text('/'),
                DevToolsButton(
                  outlined: false,
                  label: e.key.toString(),
                  onPressed: () => setState(
                    () => _stack.removeRange(
                      _stack.indexOf(e) + 1,
                      _stack.length,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      child: DefaultTextStyle(
        style:
            textTheme.bodyMedium?.copyWith(overflow: TextOverflow.ellipsis) ??
            const TextStyle(),
        child: DataTableView(
          key: ValueKey(widget.data.name),
          data: stack.last.value,
          onStack: (key, value) =>
              setState(() => _stack.add(KeyedObject(key, value))),
        ),
      ),
    );
  }
}

@immutable
class KeyedObject<T extends Object?> {
  final Object key;
  final T value;

  // Load the value if it is lazy
  final VoidCallback? load;

  bool get lazy => load != null;

  const KeyedObject(this.key, this.value, {this.load});
}

class DataTableView extends StatefulWidget {
  final List<KeyedObject> data;
  final void Function(Object key, List<KeyedObject> value) onStack;

  const DataTableView({super.key, required this.data, required this.onStack});

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
    if (firstValue is RawObject) {
      columnCount = 1 + firstValue.fields.length;
    } else {
      columnCount = 2;
    }

    final query = searchController.text;
    final List<KeyedObject> filteredData;
    if (query.isEmpty) {
      filteredData = widget.data;
    } else {
      filteredData = widget.data
          .where(
            (e) =>
                e.key.toString().toLowerCase().contains(query.toLowerCase()) ||
                e.value.toString().toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }

    final largeDataset = widget.data.length > 100000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: DevToolsClearableTextField(
                  controller: searchController,
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: !largeDataset ? (_) => setState(() {}) : null,
                  onSubmitted: largeDataset ? (_) => setState(() {}) : null,
                ),
              ),
              if (largeDataset) const Text('Submit to search'),
            ],
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
                  rowBuilder: (index) => const TableSpan(
                    extent: FixedSpanExtent(20),
                    padding: SpanPadding.all(4),
                  ),
                  columnBuilder: (index) => const TableSpan(
                    extent: FixedSpanExtent(100),
                    padding: SpanPadding.all(8),
                  ),
                  cellBuilder: (context, vicinity) {
                    final TableVicinity(:row, :column) = vicinity;
                    final rowIndex = row - 1;
                    final columnIndex = column - 1;

                    if (row == 0 && column == 0) {
                      return const TableViewCell(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('key'),
                        ),
                      );
                    }

                    final String fieldName;
                    if (firstValue is RawObject && column > 0) {
                      fieldName = firstValue.fields[columnIndex].name;
                    } else {
                      fieldName = columnIndex.toString();
                    }

                    if (row == 0) {
                      return TableViewCell(
                        child: DataCellContent(
                          tooltip: fieldName,
                          child: Text(fieldName),
                        ),
                      );
                    }

                    final object = filteredData[rowIndex];

                    if (column == 0) {
                      final keyString = object.key.toString();
                      return TableViewCell(
                        child: DataCellContent(
                          tooltip: keyString,
                          query: query,
                          child: Text(keyString),
                        ),
                      );
                    }

                    final objectValue = object.value;
                    final Object? fieldValue;
                    if (objectValue is RawObject) {
                      fieldValue = objectValue.fields[columnIndex].value;
                    } else {
                      fieldValue = objectValue;
                    }

                    final String cellText;
                    final Widget cellContent;
                    final stackKey = '${object.key}.$fieldName';
                    if (object.lazy) {
                      cellText = '[Loading...]';
                      cellContent = const Text('[Loading...]');
                    } else if (fieldValue is Uint8List) {
                      cellText = fieldValue.toString();
                      cellContent = CopyableItem(
                        item: fieldValue,
                        child: const Text('[Bytes]'),
                      );
                    } else if (fieldValue is Iterable) {
                      final list = fieldValue.toList();
                      if (list.isEmpty) {
                        cellText = '[Empty]';
                        cellContent = Text(cellText);
                      } else {
                        cellText = list.toString();
                        cellContent = InkWell(
                          child: const Text('[Iterable]'),
                          onTap: () => widget.onStack(stackKey, [
                            for (var i = 0; i < list.length; i++)
                              KeyedObject(i, list[i]),
                          ]),
                        );
                      }
                    } else if (fieldValue is RawObject) {
                      cellText = '{${fieldValue.name}}';
                      cellContent = InkWell(
                        child: Text(cellText),
                        onTap: () => widget.onStack(stackKey, [
                          KeyedObject(0, fieldValue),
                        ]),
                      );
                    } else if (fieldValue is RawEnum) {
                      cellText = '${fieldValue.name}.${fieldValue.value}';
                      cellContent = CopyableItem(
                        item: fieldValue,
                        child: Text(cellText),
                      );
                    } else {
                      cellText = fieldValue.toString();
                      cellContent = CopyableItem(
                        item: fieldValue,
                        child: Text(cellText),
                      );
                    }

                    return TableViewCell(
                      child: FrameLoader(
                        key: ValueKey(object.key),
                        object: object,
                        child: DataCellContent(
                          tooltip: cellText,
                          getSearchableString: fieldValue.toString,
                          query: query,
                          child: cellContent,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
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

class CopyableItem extends StatelessWidget {
  final Object? item;
  final Widget child;

  const CopyableItem({super.key, required this.item, required this.child});

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: item.toString()));
        messenger.showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      },
      child: child,
    );
  }
}

class DataCellContent extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final ValueGetter<String>? getSearchableString;
  final String? query;

  const DataCellContent({
    super.key,
    required this.child,
    required this.tooltip,
    this.getSearchableString,
    this.query,
  });

  @override
  Widget build(BuildContext context) {
    Widget widget = DevToolsTooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );

    final query = this.query;
    if (query != null && query.isNotEmpty) {
      final searchable = getSearchableString?.call() ?? tooltip;
      if (searchable.toLowerCase().contains(query.toLowerCase())) {
        widget = ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ColoredBox(color: Colors.yellow.withAlpha(50), child: widget),
        );
      }
    }

    return widget;
  }
}
