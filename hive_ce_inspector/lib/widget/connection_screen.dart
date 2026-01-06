import 'package:devtools_extensions/devtools_extensions.dart';
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
  @override
  Widget build(BuildContext context) {
    const loading = Center(child: CircularProgressIndicator());

    return ValueListenableBuilder(
      valueListenable: serviceManager.connectedState,
      builder: (context, serviceConnection, child) => ValueListenableBuilder(
        valueListenable: dtdManager.connection,
        builder: (context, dtdConnection, child) {
          if (serviceConnection.connected && dtdConnection != null) {
            return FutureBuilder(
              future: ConnectClient.connect(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (data != null) {
                  return _BoxesLoader(client: data);
                } else {
                  return loading;
                }
              },
            );
          } else {
            return loading;
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
      // Wait and try again
      await Future.delayed(const Duration(seconds: 1));
      _initState();
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
