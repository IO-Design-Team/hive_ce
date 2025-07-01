import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:hive_ce_inspector/model/hive_internal.dart';
import 'package:hive_ce_inspector/widget/connection_screen.dart';
import 'package:yaml/yaml.dart';

class SchemaUploadScreen extends StatefulWidget {
  final String port;
  final String secret;

  const SchemaUploadScreen({
    super.key,
    required this.port,
    required this.secret,
  });

  @override
  State<StatefulWidget> createState() => _SchemaUploadScreenState();
}

class _SchemaUploadScreenState extends State<SchemaUploadScreen> {
  DropzoneViewController? dropzoneController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DropzoneView(
            onCreated: (controller) => dropzoneController = controller,
            onDropFile: onDropFile,
          ),
          const Center(
            child: Text(
              'Drop a Hive schema here to continue',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  void onDropFile(DropzoneFileInterface file) async {
    final navigator = Navigator.of(context);

    final dropzoneController = this.dropzoneController;
    if (dropzoneController == null) return;
    final data = await dropzoneController.getFileData(file);
    final schemaContent = utf8.decode(data);
    final schema = HiveSchema.fromJson(
      jsonDecode(jsonEncode(loadYaml(schemaContent))),
    );

    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder:
              (context) => ConnectionScreen(
                port: widget.port,
                secret: widget.secret,
                schema: schema,
              ),
        ),
      ),
    );
  }
}
