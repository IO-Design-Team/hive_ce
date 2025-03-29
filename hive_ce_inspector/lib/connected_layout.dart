import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/connect_client.dart';
import 'package:hive_ce_inspector/hive_internal.dart';

class ConnectedLayout extends StatefulWidget {
  final ConnectClient client;
  final List<String> boxes;

  const ConnectedLayout({super.key, required this.client, required this.boxes});

  @override
  State<StatefulWidget> createState() => _ConnectedLayoutState();
}

class BoxData {
  final String name;
  final Map<Object, InspectorFrame> frames;
  final bool open;

  BoxData({
    required this.name,
    Map<Object, InspectorFrame>? frames,
    this.open = true,
  }) : frames = frames ?? {};

  BoxData copyWith({bool? open}) =>
      BoxData(name: name, frames: frames, open: open ?? this.open);
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
            Expanded(child: BoxView(data: selectedBoxData)),
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

class BoxView extends StatelessWidget {
  final BoxData data;

  const BoxView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) {
        final frame = data.frames.values.toList().reversed.elementAt(index);
        return Row(
          children: [Text(frame.key.toString()), Text(frame.value.toString())],
        );
      },
      itemCount: data.frames.length,
    );
  }
}
