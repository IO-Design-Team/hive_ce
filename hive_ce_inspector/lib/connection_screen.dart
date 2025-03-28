import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/connect_client.dart';
import 'package:hive_ce_inspector/connected_layout.dart';
import 'package:hive_ce_inspector/error_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    required this.version,
    required this.port,
    required this.secret,
    super.key,
  });

  final String version;
  final String port;
  final String secret;

  @override
  State<ConnectionScreen> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionScreen> {
  late Future<ConnectClient> clientFuture;

  @override
  void initState() {
    clientFuture = ConnectClient.connect(widget.port, widget.secret);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ConnectionScreen oldWidget) {
    if (oldWidget.port != widget.port || oldWidget.secret != widget.secret) {
      clientFuture = ConnectClient.connect(widget.port, widget.secret);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConnectClient>(
      future: clientFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _BoxesLoader(client: snapshot.data!);
        } else if (snapshot.hasError) {
          return const ErrorScreen();
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
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
  late final List<String> boxes;

  var error = false;

  @override
  void initState() {
    _initState();
    super.initState();
  }

  void _initState() async {
    try {
      final boxes = await widget.client.listBoxes();
      setState(() => this.boxes = boxes);
    } catch (_) {
      setState(() => error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error) {
      return const ErrorScreen();
    }

    if (boxes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ConnectedLayout(client: widget.client, boxes: boxes);
  }
}
