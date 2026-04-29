import 'package:flutter/material.dart';

import 'core/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  await bootstrapBrainjamin();
  runApp(const BrainjaminApp());
}

class BrainjaminApp extends StatelessWidget {
  const BrainjaminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainjamin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
        ),
        useMaterial3: true,
      ),
      home: const _SmokeTestScreen(),
    );
  }
}

class _SmokeTestScreen extends StatelessWidget {
  const _SmokeTestScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Brainjamin\nFirebase ready',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
