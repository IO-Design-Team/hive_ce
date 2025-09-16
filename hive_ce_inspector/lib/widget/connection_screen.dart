import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:hive_ce_inspector/service/connect_client.dart';
import 'package:hive_ce_inspector/widget/connected_layout.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, this.types = const {}});

  final Map<String, HiveSchemaType> types;

  @override
  State<ConnectionScreen> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionScreen> {
  late final Future<ConnectClient> clientFuture;

  @override
  void initState() {
    clientFuture = ConnectClient.connect(widget.types);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ConnectClient>(
        future: clientFuture,
        builder: (context, snapshot) {
          print(snapshot.error);
          if (snapshot.hasData) {
            return _BoxesLoader(client: snapshot.data!);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class _BoxesLoader extends StatefulWidget {
  const _BoxesLoader({required this.client});

  final ConnectClient client;

  @override
  State<_BoxesLoader> createState() => _BoxesLoaderState();
}

class _BoxesLoaderState extends State<_BoxesLoader> {
  final boxes = <String>[];

  var error = false;

  @override
  void initState() {
    _initState();
    super.initState();
  }

  void _initState() async {
    try {
      final boxes = await widget.client.listBoxes();
      setState(() => this.boxes.addAll(boxes));
    } catch (_) {
      setState(() => error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (boxes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ConnectedLayout(client: widget.client, boxes: boxes);
  }
}
