import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_inspector/widget/connection_screen.dart';

void main() {
  runApp(
    DevToolsExtension(
      child: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (context) => const ConnectionScreen(),
        ),
      ),
    ),
  );
}
