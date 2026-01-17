import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/service/connect_client.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:hive_ce_inspector/model/box_data.dart';
import 'package:hive_ce_inspector/widget/box_view.dart';

class ConnectedLayout extends StatefulWidget {
  final ConnectClient client;
  final List<String> boxes;

  const ConnectedLayout({super.key, required this.client, required this.boxes});

  @override
  State<StatefulWidget> createState() => _ConnectedLayoutState();
}

class _ConnectedLayoutState extends State<ConnectedLayout> {
  final boxData = <String, BoxData>{};

  late final StreamSubscription<String> boxRegisteredSubscription;
  late final StreamSubscription<String> boxUnregisteredSubscription;
  late final StreamSubscription<BoxEventPayload> boxEventSubscription;

  String? selectedBox;
  HiveSchema? schema;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    for (final box in widget.boxes) {
      boxData[box] = BoxData(name: box);
    }

    boxRegisteredSubscription = widget.client.boxRegistered.listen(
      (name) => setState(() => boxData[name] = BoxData(name: name)),
    );
    boxUnregisteredSubscription = widget.client.boxUnregistered.listen(
      (name) => setState(
        () => boxData.update(name, (value) => value.copyWith(open: false)),
      ),
    );

    boxEventSubscription = widget.client.boxEvent.listen((event) {
      boxData[event.box]?.frames[event.frame.key] = event.frame;

      // Do not call set state for unfocused boxes for performance reasons
      if (selectedBox == event.box) setState(() {});
    });
  }

  @override
  void dispose() {
    boxRegisteredSubscription.cancel();
    boxUnregisteredSubscription.cancel();
    boxEventSubscription.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedBox = this.selectedBox;
    final selectedBoxData = boxData[selectedBox];
    final query = searchController.text;
    final filteredBoxes = boxData.keys
        .where((b) => b.toLowerCase().contains(query.toLowerCase()))
        .toList();
    

    return SplitPane(
      axis: Axis.horizontal,
      initialFractions: const [0.2, 0.8],
      children: [
        DevToolsAreaPane(
          header: const AreaPaneHeader(title: Text('Boxes')),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: DevToolsClearableTextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => setState(() {}),
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search boxes',
                ),
              ),
              Expanded(
                child: filteredBoxes.isEmpty
                    ? Center(child: Text('No boxes matching "$query"'))
                    : ListView.builder(
                        itemBuilder: (context, index) {
                          final box = filteredBoxes[index];
                          return ListTile(
                            title: Text(box),
                            selected: selectedBox == box,
                            onTap: () {
                              loadBoxData(box);
                              setState(() => this.selectedBox = box);
                            },
                          );
                        },
                        itemCount: filteredBoxes.length,
                      ),
              ),
            ],
          ),
        ),
        if (selectedBox == null)
          const Center(child: Text('Select a box'))
        else if (selectedBoxData == null)
          const Center(child: CircularProgressIndicator())
        else
          BoxView(
            key: ValueKey(selectedBox),
            client: widget.client,
            data: selectedBoxData,
          ),
      ],
    );
  }

  void loadBoxData(String box) async {
    final data = boxData[box];
    if (data == null || data.loaded) return;

    final frames = await widget.client.getBoxFrames(box);
    setState(
      () => boxData[box] = BoxData(
        name: box,
        frames: {for (final frame in frames) frame.key: frame},
        loaded: true,
      ),
    );
  }
}
