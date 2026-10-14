// Hosted by DevTools, which still provides the in-framework Material theme.
// ignore_for_file: unnecessary_ignore, deprecated_member_use
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/widget/connection_screen.dart';

void main() {
  runApp(const DevToolsExtension(child: ConnectionScreen()));
}
