import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
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
  DropzoneViewController? dropzoneController;
  HiveSchema? schema;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedBox = this.selectedBox;
    final selectedBoxData = boxData[selectedBox];

    final isWide = MediaQuery.of(context).size.width > 600;
    final drawer = Drawer(
      child: ListView.builder(
        itemBuilder: (context, index) {
          final box = boxData.keys.elementAt(index);
          return ListTile(
            style: ListTileStyle.drawer,
            title: Text(box),
            selected: selectedBox == box,
            onTap: () {
              loadBoxData(box);
              setState(() => this.selectedBox = box);
            },
          );
        },
        itemCount: boxData.keys.length,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Hive CE Inspector')),
      drawer: isWide ? null : drawer,
      body: Row(
        children: [
          if (isWide) drawer,
          if (selectedBox == null)
            const Expanded(child: Center(child: Text('Select a box')))
          else if (selectedBoxData == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: BoxView(
                key: ValueKey(selectedBox),
                client: widget.client,
                data: selectedBoxData,
              ),
            ),
        ],
      ),
    );
  }

  void loadBoxData(String box) async {
    final data = boxData[box];
    if (data == null || data.loaded) return;

    final frames = await widget.client.getBoxFrames(box);
    setState(
      () =>
          boxData[box] = BoxData(
            name: box,
            frames: {for (final frame in frames) frame.key: frame},
            loaded: true,
          ),
    );
  }
}
