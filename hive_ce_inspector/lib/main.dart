import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'package:hive_ce_inspector/widget/root_screen.dart';
import 'package:hive_ce_inspector/widget/schema_upload_screen.dart';

void main() {
  usePathUrlStrategy();
  runApp(DarkMode(notifier: DarkModeNotifier(), child: const App()));
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
          seedColor: const Color(0xFF9FC9FF),
          brightness:
              DarkMode.of(context).darkMode
                  ? Brightness.dark
                  : Brightness.light,
        ),
        useMaterial3: true,
      ),
    );
  }
}

class DarkMode extends InheritedNotifier<DarkModeNotifier> {
  const DarkMode({required super.child, super.key, super.notifier});

  static DarkModeNotifier of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DarkMode>()!.notifier!;
  }
}

class DarkModeNotifier extends ChangeNotifier {
  var _darkMode = true;

  bool get darkMode => _darkMode;

  void toggle() {
    _darkMode = !_darkMode;
    notifyListeners();
  }
}
