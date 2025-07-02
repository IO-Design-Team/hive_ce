import 'package:flutter/material.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Disconnected', style: TextStyle(fontSize: 20)),
          SizedBox(height: 10),
          Text(
            'Please make sure your Hive CE instance is running and try again.',
          ),
        ],
      ),
    );
  }
}
