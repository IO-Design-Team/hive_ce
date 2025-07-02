import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'package:hive_ce_inspector/widget/root_screen.dart';
import 'package:hive_ce_inspector/widget/schema_upload_screen.dart';

void main() {
  usePathUrlStrategy();
  runApp(const App());
}

final _router = GoRouter(
  routes: <GoRoute>[
    GoRoute(path: '/', builder: (context, state) => const RootScreen()),
    GoRoute(
      path: '/:port/:secret',
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: SchemaUploadScreen(
            port: state.pathParameters['port']!,
            secret: state.pathParameters['secret']!,
          ),
        );
      },
    ),
  ],
);

class App extends StatelessWidget {
  static const _seedColor = Color(0xFF9FC9FF);

  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Hive CE Inspector',
      routeInformationProvider: _router.routeInformationProvider,
      routeInformationParser: _router.routeInformationParser,
      routerDelegate: _router.routerDelegate,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
    );
  }
}
