import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/connect_client.dart';
import 'package:hive_ce_inspector/hive_internal.dart';

class ConnectedLayout extends StatefulWidget {
  final ConnectClient client;
  final Set<String> boxes;

  const ConnectedLayout({super.key, required this.client, required this.boxes});

  @override
  State<StatefulWidget> createState() => _ConnectedLayoutState();
}

class _ConnectedLayoutState extends State<ConnectedLayout> {
  final boxData = <String, Map<Object, InspectorFrame>>{};

  String? selectedBox;

  @override
  void initState() {
    super.initState();
    widget.client.boxEvent.listen((event) {
      setState(() => boxData[event.name]?[event.frame.key] = event.frame);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hive CE Inspector')),
      body: ListView.builder(
        itemBuilder: (context, index) => Text(widget.boxes.elementAt(index)),
        itemCount: widget.boxes.length,
      ),
    );
  }
}
