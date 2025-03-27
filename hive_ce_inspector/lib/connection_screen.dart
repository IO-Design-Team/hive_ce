import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/connect_client.dart';
import 'package:hive_ce_inspector/error_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({required this.port, required this.secret, super.key});

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
          return const Loading();
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
  final Set<String> boxes = {};
  late StreamSubscription<String> boxRegisteredSubscription;
  late StreamSubscription<String> boxUnregisteredSubscription;

  @override
  void initState() {
    _initState();
    boxRegisteredSubscription = widget.client.boxRegistered.listen(
      (name) => setState(() => boxes.add(name)),
    );
    boxUnregisteredSubscription = widget.client.boxUnregistered.listen(
      (name) => setState(() => boxes.remove(name)),
    );
    super.initState();
  }

  void _initState() async {
    final boxes = await widget.client.listBoxes();
    setState(() => boxes.addAll(boxes));
  }

  @override
  void dispose() {
    boxRegisteredSubscription.cancel();
    boxUnregisteredSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (boxes.isEmpty) {
      return const Loading();
    }

    return ListView.builder(
      itemBuilder: (context, index) => Text(boxes.elementAt(index)),
      itemCount: boxes.length,
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
