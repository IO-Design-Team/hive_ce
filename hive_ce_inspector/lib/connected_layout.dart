import 'package:flutter/material.dart';

class ConnectedLayout extends StatefulWidget {
  final Set<String> boxes;

  const ConnectedLayout({super.key, required this.boxes});

  @override
  State<StatefulWidget> createState() => _ConnectedLayoutState();
}

class _ConnectedLayoutState extends State<ConnectedLayout> {
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
