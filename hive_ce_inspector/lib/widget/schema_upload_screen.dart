import 'dart:async';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:hive_ce_inspector/widget/connection_screen.dart';
import 'package:yaml/yaml.dart';

class SchemaUploadScreen extends StatelessWidget {
  const SchemaUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return Scaffold(
      body: DropTarget(
        onDragDone: (details) => onDragDone(navigator, details),
        child: const Center(
          child: Text(
            'Drop a Hive schema here to continue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  void onDragDone(NavigatorState navigator, DropDoneDetails details) async {
    final content = await details.files.first.readAsString();
    final schema = HiveSchema.fromJson(
      jsonDecode(jsonEncode(loadYaml(content))),
    );

    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ConnectionScreen(types: schema.types),
        ),
      ),
    );
  }
}
