import 'dart:async';

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

    boxEventSubscription = widget.client.boxEvent.listen(
      (event) => setState(
        () => boxData[event.box]?.frames[event.frame.key] = event.frame,
      ),
    );
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
    final isWide = MediaQuery.of(context).size.width > 600;
    final drawer = Drawer(
      child: ListView.builder(
        itemBuilder: (context, index) {
          final box = boxData.keys.elementAt(index);
          return ListTile(
            style: ListTileStyle.drawer,
            title: Text(box),
            onTap: () {
              loadBoxData(box);
              setState(() => this.selectedBox = box);
            },
          );
        },
        itemCount: boxData.keys.length,
      ),
    );

    final selectedBox = this.selectedBox;
    final selectedBoxData = boxData[selectedBox];

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
              child: BoxView(client: widget.client, data: selectedBoxData),
            ),
        ],
      ),
    );
  }

  void loadBoxData(String box) async {
    final frames = await widget.client.getBoxFrames(box);
    setState(
      () =>
          boxData[box] = BoxData(
            name: box,
            frames: {for (final frame in frames) frame.key: frame},
          ),
    );
  }
}
