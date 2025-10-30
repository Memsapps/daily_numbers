import 'package:flutter/material.dart';
void main() => runApp(const ProbeApp());
class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PROBE 2025-10-23 07:53:48',
      home: Scaffold(
        appBar: AppBar(title: const Text('PROBE BUILD')),
        body: Center(
          child: Text(
            'PROBE: 2025-10-23 07:53:48\ned860115-4c59-4af5-8289-6b15ca5b4261',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}
