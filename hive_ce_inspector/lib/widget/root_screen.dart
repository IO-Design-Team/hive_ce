import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Welcome to the Hive CE Inspector!\nPlease open the link '
            'displayed when running the debug version of a Hive CE app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          const Text(
            "If that's how you got here, paste the VM Service URL from the debug console below",
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextField(
              controller: _urlController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'ws://127.0.0.1:12345/abcdefghijk=/ws',
              ),
              onSubmitted: (_) => reloadWithUrl(),
            ),
          ),
        ],
      ),
    );
  }

  void reloadWithUrl() {
    final uri = Uri.tryParse(_urlController.text);
    if (uri == null) return;

    final port = uri.port;
    var path = uri.pathSegments.first;
    if (path.endsWith('=')) {
      path = path.substring(0, path.length - 1);
    }

    context.go('/$port/$path');
  }
}
