import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/model/box_data.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';

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
          child: ListView.builder(
            itemBuilder: (context, index) {
              final frame = filteredFrames.reversed.elementAt(index);
              return Row(
                children: [
                  Text(frame.key.toString()),
                  Text(frame.value.toString()),
                ],
              );
            },
            itemCount: filteredFrames.length,
          ),
        ),
      ],
    );
  }
}
