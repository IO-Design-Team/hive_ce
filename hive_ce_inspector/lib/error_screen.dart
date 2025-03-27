import 'package:flutter/material.dart';
import 'package:web/web.dart' show window;

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Disconnected', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 10),
          const Text('Please make sure your Hive CE instance is running.'),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: window.location.reload,
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }
}
